#!/usr/bin/env bash
# tui/bootloader_select.sh — Bootloader selection (Alpine uses GRUB only)
source "${LIB_DIR}/protection.sh"

screen_bootloader_select() {
    # Alpine Linux doesn't have systemd, so systemd-boot is not available.
    # Default to GRUB without showing a selection screen.
    BOOTLOADER_TYPE="grub"
    export BOOTLOADER_TYPE

    einfo "Bootloader: ${BOOTLOADER_TYPE}"
    return "${TUI_NEXT}"
}
