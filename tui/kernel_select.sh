#!/usr/bin/env bash
# tui/kernel_select.sh — Kernel selection: LTS or virt
source "${LIB_DIR}/protection.sh"

screen_kernel_select() {
    local current="${KERNEL_TYPE:-lts}"
    local on_lts="off" on_virt="off"
    case "${current}" in
        lts)  on_lts="on" ;;
        virt) on_virt="on" ;;
    esac

    local choice
    choice=$(dialog_radiolist "Kernel Selection" \
        "lts"  "linux-lts — Long Term Support (recommended)" "${on_lts}" \
        "virt" "linux-virt — Lightweight virtual/cloud kernel" "${on_virt}") \
        || return "${TUI_BACK}"

    if [[ -z "${choice}" ]]; then
        return "${TUI_BACK}"
    fi

    KERNEL_TYPE="${choice}"
    export KERNEL_TYPE

    einfo "Kernel: linux-${KERNEL_TYPE}"
    return "${TUI_NEXT}"
}
