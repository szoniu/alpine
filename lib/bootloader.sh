#!/usr/bin/env bash
# bootloader.sh — GRUB or systemd-boot installation for Alpine Linux
source "${LIB_DIR}/protection.sh"

# bootloader_install — Install and configure bootloader
bootloader_install() {
    local boot_type="${BOOTLOADER_TYPE:-grub}"

    case "${boot_type}" in
        grub)
            _install_grub
            ;;
        systemd-boot)
            _install_systemd_boot
            ;;
    esac
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

    # Configure /etc/default/grub BEFORE grub-install (LUKS requires CRYPTODISK=y at install time)
    chroot_exec "mkdir -p /etc/default"
    chroot_exec "cat > /etc/default/grub << 'GRUBEOF'
GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_TIMEOUT_STYLE=menu
GRUB_DISTRIBUTOR=\"Alpine\"
GRUB_CMDLINE_LINUX_DEFAULT=\"quiet\"
GRUBEOF"

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

# _install_systemd_boot — Install systemd-boot (gummiboot)
_install_systemd_boot() {
    einfo "Installing systemd-boot bootloader..."

    # Alpine provides efibootmgr and can use systemd-boot standalone
    apk_install "Installing systemd-boot tools" efibootmgr

    # Ensure ESP is mounted at /boot (systemd-boot uses /boot, not /boot/efi)
    if [[ -n "${ESP_PARTITION:-}" ]] && ! mountpoint -q "${MOUNTPOINT}/boot" 2>/dev/null; then
        einfo "Re-mounting ESP at /boot..."
        mkdir -p "${MOUNTPOINT}/boot"
        try "Mounting ESP" mount "${ESP_PARTITION}" "${MOUNTPOINT}/boot"
    fi

    # Install bootctl if available, otherwise manual setup
    if chroot_exec "command -v bootctl" &>/dev/null; then
        try "Installing systemd-boot" \
            chroot_exec "bootctl install"
    else
        # Manual systemd-boot installation
        einfo "Manual systemd-boot setup (bootctl not available)..."
        chroot_exec "mkdir -p /boot/EFI/systemd /boot/EFI/BOOT /boot/loader/entries"

        # Copy systemd-boot EFI binary from host or download
        if [[ -f /usr/lib/systemd/boot/efi/systemd-bootx64.efi ]]; then
            cp /usr/lib/systemd/boot/efi/systemd-bootx64.efi \
                "${MOUNTPOINT}/boot/EFI/systemd/systemd-bootx64.efi"
            cp /usr/lib/systemd/boot/efi/systemd-bootx64.efi \
                "${MOUNTPOINT}/boot/EFI/BOOT/BOOTX64.EFI"
        fi
    fi

    # Generate boot entries manually
    _generate_systemd_boot_entries

    # LUKS support: regenerate initramfs
    if [[ "${LUKS_ENABLED:-no}" == "yes" ]]; then
        try "Regenerating initramfs with LUKS support" \
            chroot_exec "mkinitfs"
        _generate_systemd_boot_entries
    fi

    einfo "systemd-boot installed"
}

# _generate_systemd_boot_entries — Create loader.conf and boot entry
_generate_systemd_boot_entries() {
    local kernel_type="${KERNEL_TYPE:-lts}"

    # Loader configuration
    chroot_exec "cat > /boot/loader/loader.conf << 'LOADEREOF'
default alpine.conf
timeout 5
console-mode max
LOADEREOF"

    # Determine root device for kernel cmdline
    local root_param=""
    if [[ "${LUKS_ENABLED:-no}" == "yes" ]]; then
        local luks_uuid
        luks_uuid=$(get_uuid "${LUKS_PARTITION}")
        root_param="cryptdevice=UUID=${luks_uuid}:cryptroot root=/dev/mapper/cryptroot"
    else
        local root_uuid
        root_uuid=$(get_uuid "${ROOT_PARTITION}")
        if [[ -n "${root_uuid}" ]]; then
            root_param="root=UUID=${root_uuid}"
        else
            root_param="root=${ROOT_PARTITION}"
        fi
    fi

    # Find kernel and initramfs filenames
    local vmlinuz_name="vmlinuz-${kernel_type}"
    local initramfs_name="initramfs-${kernel_type}"

    # Boot entry
    chroot_exec "cat > /boot/loader/entries/alpine.conf << ENTRYEOF
title   Alpine Linux
linux   /${vmlinuz_name}
initrd  /${initramfs_name}
options ${root_param} rw quiet
ENTRYEOF"
}
