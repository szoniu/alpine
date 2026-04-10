#!/usr/bin/env bash
# bootstrap.sh — Alpine Linux base system installation via apk
source "${LIB_DIR}/protection.sh"

# Default Alpine mirror
: "${ALPINE_MIRROR:=https://dl-cdn.alpinelinux.org/alpine}"
# Alpine release branch (v3.23 for stable, edge for latest)
: "${ALPINE_BRANCH:=v3.21}"

# bootstrap_install — Install base Alpine Linux system using apk --root
bootstrap_install() {
    einfo "Installing Alpine Linux base system..."

    if [[ "${DRY_RUN}" == "1" ]]; then
        einfo "[DRY-RUN] Would bootstrap Alpine Linux to ${MOUNTPOINT}"
        return 0
    fi

    # If retrying after a failed attempt, clean up
    if [[ -d "${MOUNTPOINT}" ]] && [[ -n "$(ls -A "${MOUNTPOINT}" 2>/dev/null)" ]]; then
        ewarn "Target directory ${MOUNTPOINT} is not empty — cleaning up"

        # Unmount ALL nested mounts (including ESP)
        local -a nested_mounts
        readarray -t nested_mounts < <(awk -v mp="${MOUNTPOINT}" \
            '$2 ~ "^"mp"/" {print $2}' \
            /proc/mounts 2>/dev/null | sort -r)
        local m
        for m in "${nested_mounts[@]}"; do
            [[ -z "${m}" ]] && continue
            umount -l "${m}" 2>/dev/null || true
        done

        # Remove ALL contents
        find "${MOUNTPOINT}" -mindepth 1 -maxdepth 1 \
            -exec rm -rf {} + 2>/dev/null || true
    fi

    # Set up apk repositories for the target system
    mkdir -p "${MOUNTPOINT}/etc/apk"
    cat > "${MOUNTPOINT}/etc/apk/repositories" << REPOEOF
${ALPINE_MIRROR}/${ALPINE_BRANCH}/main
${ALPINE_MIRROR}/${ALPINE_BRANCH}/community
REPOEOF

    # Copy host DNS for network access during bootstrap
    mkdir -p "${MOUNTPOINT}/etc"
    cp -L /etc/resolv.conf "${MOUNTPOINT}/etc/resolv.conf" 2>/dev/null || true

    # Initialize apk keys (needed for signature verification)
    mkdir -p "${MOUNTPOINT}/etc/apk/keys"
    cp -a /etc/apk/keys/* "${MOUNTPOINT}/etc/apk/keys/" 2>/dev/null || true

    # Bootstrap base system using apk --root
    # alpine-base provides OpenRC, busybox, apk-tools, musl, and core system
    try "Bootstrap Alpine Linux base system" \
        apk add --root "${MOUNTPOINT}" --initdb \
            --repositories-file="${MOUNTPOINT}/etc/apk/repositories" \
            alpine-base

    # Re-mount ESP if it was unmounted during cleanup
    if [[ -n "${ESP_PARTITION:-}" ]]; then
        local esp_path="${MOUNTPOINT}/boot/efi"
        [[ "${BOOTLOADER_TYPE:-grub}" == "systemd-boot" ]] && esp_path="${MOUNTPOINT}/boot"
        mkdir -p "${esp_path}"
        if ! mountpoint -q "${esp_path}" 2>/dev/null; then
            mount "${ESP_PARTITION}" "${esp_path}" 2>/dev/null || true
        fi
    fi

    einfo "Base system installed to ${MOUNTPOINT}"
}

# apk_update — Update package database and upgrade
apk_update() {
    einfo "Updating package database..."

    try "Updating apk index" \
        chroot_exec "apk update"

    try "Upgrading packages" \
        chroot_exec "apk upgrade --available"

    # Essential tools for daily use
    einfo "Installing essential tools..."
    apk_install "Installing essential tools" \
        curl wget git build-base pkgconf

    einfo "Packages up to date"
}

# apk_install — Install packages via apk inside chroot
# Usage: apk_install "description" pkg1 pkg2 ...
apk_install() {
    local desc="$1"
    shift
    local -a pkgs=("$@")

    if [[ ${#pkgs[@]} -eq 0 ]]; then
        return 0
    fi

    try "${desc}" \
        chroot_exec "apk add ${pkgs[*]}"
}

# apk_install_if_available — Install package only if it exists in repo
apk_install_if_available() {
    local pkg="$1"

    if chroot_exec "apk search -e ${pkg}" >> "${LOG_FILE}" 2>&1; then
        try "Installing ${pkg}" chroot_exec "apk add ${pkg}"
    else
        ewarn "Package ${pkg} not found in repositories, skipping"
    fi
}

# enable_community_repo — Ensure community repository is enabled
enable_community_repo() {
    einfo "Ensuring community repository is enabled..."
    local repos="${MOUNTPOINT}/etc/apk/repositories"
    if ! grep -q "community" "${repos}" 2>/dev/null; then
        echo "${ALPINE_MIRROR}/${ALPINE_BRANCH}/community" >> "${repos}"
        try "Updating repos" chroot_exec "apk update"
    fi
}

# enable_testing_repo — Enable testing repository (for bleeding-edge packages)
enable_testing_repo() {
    einfo "Enabling testing repository..."
    local repos="${MOUNTPOINT}/etc/apk/repositories"
    if ! grep -q "testing" "${repos}" 2>/dev/null; then
        echo "${ALPINE_MIRROR}/edge/testing" >> "${repos}"
        try "Updating repos" chroot_exec "apk update"
    fi
}

# --- Peripheral install functions ---

# install_fingerprint_tools — Install fingerprint reader support
install_fingerprint_tools() {
    if [[ "${ENABLE_FINGERPRINT:-no}" != "yes" ]]; then
        return 0
    fi
    einfo "Installing fingerprint reader support..."
    apk_install "Installing fprintd" fprintd libfprint
    einfo "Fingerprint support installed"
}

# install_thunderbolt_tools — Install Thunderbolt device manager
install_thunderbolt_tools() {
    if [[ "${ENABLE_THUNDERBOLT:-no}" != "yes" ]]; then
        return 0
    fi
    einfo "Installing Thunderbolt support..."
    apk_install "Installing bolt" bolt
    einfo "Thunderbolt support installed"
}

# install_sensor_tools — Install IIO sensor proxy
install_sensor_tools() {
    if [[ "${ENABLE_SENSORS:-no}" != "yes" ]]; then
        return 0
    fi
    einfo "Installing IIO sensor support..."
    apk_install "Installing iio-sensor-proxy" iio-sensor-proxy
    einfo "IIO sensor support installed"
}

# install_wwan_tools — Install WWAN/LTE modem support
install_wwan_tools() {
    if [[ "${ENABLE_WWAN:-no}" != "yes" ]]; then
        return 0
    fi
    einfo "Installing WWAN/LTE support..."
    apk_install "Installing ModemManager" modemmanager libmbim libqmi
    einfo "WWAN/LTE support installed"
}
