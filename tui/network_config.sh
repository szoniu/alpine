#!/usr/bin/env bash
# tui/network_config.sh — Hostname configuration
source "${LIB_DIR}/protection.sh"

screen_network_config() {
    local hostname
    hostname=$(dialog_inputbox "Hostname" \
        "Enter the hostname for this system:" \
        "${HOSTNAME:-alpine}") || return "${TUI_BACK}"

    if [[ -z "${hostname}" ]]; then
        hostname="alpine"
    fi

    HOSTNAME="${hostname}"
    export HOSTNAME

    einfo "Hostname: ${HOSTNAME}"
    return "${TUI_NEXT}"
}
