#!/usr/bin/env bash
# bootloader.sh — GRUB (UEFI) installation for Alpine Linux
#
# Alpine has no systemd, so systemd-boot/bootctl is unavailable. GRUB is the
# only supported bootloader (full UEFI + LUKS + dual-boot support).
source "${LIB_DIR}/protection.sh"

# bootloader_install — Install and configure the bootloader
bootloader_install() {
    _install_grub
}

# _install_grub — Install GRUB for x86_64 EFI
_install_grub() {
    einfo "Installing GRUB bootloader..."

    apk_install "Installing GRUB" grub grub-efi

    # Ensure ESP is mounted
    local efi_dir="/boot/efi"
    if [[ -n "${ESP_PARTITION:-}" ]] && ! mountpoint -q "${MOUNTPOINT}${efi_dir}" 2>/dev/null; then
        einfo "Re-mounting ESP at ${efi_dir}..."
        mkdir -p "${MOUNTPOINT}${efi_dir}"
        try "Mounting ESP" mount "${ESP_PARTITION}" "${MOUNTPOINT}${efi_dir}"
    fi

    # Build kernel cmdline (GRUB_CMDLINE_LINUX_DEFAULT)
    local default_params="quiet"

    # UMPC portrait-panel quirk: fbcon for early console + panel_orientation
    # for KMS-aware compositors (KWin, Mutter). Without this the first boot
    # (GRUB → console → SDDM/GDM → Plasma/GNOME) shows the image rotated
    # because the panel is mounted physically rotated relative to the casing.
    if [[ "${UMPC_DETECTED:-0}" == "1" ]] && [[ -n "${UMPC_PANEL_ORIENTATION:-}" ]]; then
        default_params="${default_params} fbcon=rotate:${UMPC_FBCON_ROTATE} video=${UMPC_VIDEO_CONNECTOR}:panel_orientation=${UMPC_PANEL_ORIENTATION}"
        einfo "UMPC panel rotation applied to GRUB_CMDLINE_LINUX_DEFAULT"
    fi

    # Configure /etc/default/grub BEFORE grub-install (LUKS requires CRYPTODISK=y at install time)
    chroot_exec "mkdir -p /etc/default"
    chroot_exec "cat > /etc/default/grub << 'GRUBEOF'
GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_TIMEOUT_STYLE=menu
GRUB_DISTRIBUTOR=\"Alpine\"
GRUB_CMDLINE_LINUX_DEFAULT=\"__DEFAULT_PARAMS__\"
GRUBEOF"
    # Inject the assembled kernel cmdline (kept out of the quoted heredoc so
    # the params — incl. UMPC video= with ':' — are written verbatim).
    chroot_exec "sed -i 's|__DEFAULT_PARAMS__|${default_params}|' /etc/default/grub"

    if [[ "${LUKS_ENABLED:-no}" == "yes" ]]; then
        chroot_exec "cat >> /etc/default/grub << 'GRUBEOF'

# LUKS encryption support
GRUB_CMDLINE_LINUX=\"root=/dev/mapper/cryptroot\"
GRUB_ENABLE_CRYPTODISK=y
GRUBEOF"
    fi

    if [[ "${PARTITION_SCHEME:-}" == "dual-boot" ]]; then
        apk_install_if_available os-prober
        chroot_exec "echo 'GRUB_DISABLE_OS_PROBER=false' >> /etc/default/grub" || true
    fi

    # Install GRUB to ESP with unique bootloader-id
    try "Installing GRUB to ${efi_dir}" \
        chroot_exec "grub-install --target=x86_64-efi --efi-directory=${efi_dir} --bootloader-id=alpine"

    # Regenerate initramfs with LUKS support if needed
    if [[ "${LUKS_ENABLED:-no}" == "yes" ]]; then
        try "Regenerating initramfs with LUKS support" \
            chroot_exec "mkinitfs"
    fi

    # Generate GRUB config (Alpine uses grub-mkconfig, not update-grub)
    try "Generating GRUB configuration" \
        chroot_exec "grub-mkconfig -o /boot/grub/grub.cfg"

    einfo "GRUB installed"
}
