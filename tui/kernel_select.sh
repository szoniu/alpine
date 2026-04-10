#!/usr/bin/env bash
# tui/kernel_select.sh — Kernel selection: LTS or edge
source "${LIB_DIR}/protection.sh"

screen_kernel_select() {
    local current="${KERNEL_TYPE:-lts}"
    local on_lts="off" on_edge="off"
    case "${current}" in
        lts)  on_lts="on" ;;
        edge) on_edge="on" ;;
    esac

    local choice
    choice=$(dialog_radiolist "Kernel Selection" \
        "lts"  "linux-lts — Long Term Support (recommended)" "${on_lts}" \
        "edge" "linux-edge — Latest edge release" "${on_edge}") \
        || return "${TUI_BACK}"

    if [[ -z "${choice}" ]]; then
        return "${TUI_BACK}"
    fi

    KERNEL_TYPE="${choice}"
    export KERNEL_TYPE

    einfo "Kernel: linux-${KERNEL_TYPE}"
    return "${TUI_NEXT}"
}
