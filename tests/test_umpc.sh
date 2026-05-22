#!/usr/bin/env bash
# tests/test_umpc.sh — UMPC support for Alpine (GPD Pocket/Win, Chuwi MiniBook X).
# Covers: CONFIG_VARS + checkpoint wiring, detect_umpc() panel orientation,
# GRUB cmdline assembly, and umpc_apply_quirks() chroot/apk emissions (OpenRC).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/_harness.sh
source "${SCRIPT_DIR}/_harness.sh"

harness_init
# shellcheck disable=SC1090
source "${LIB_DIR}/hardware.sh"
# shellcheck disable=SC1090
source "${LIB_DIR}/umpc.sh"
harness_mock

# --- detection test: re-implement detect_umpc reading from DMI_TEST_DIR ------
# (Mirrors the real detect_umpc logic; reads a fake /sys/class/dmi/id so the
# test is hardware-independent — same approach as the Gentoo test.)
test_detect_umpc() {
    local dmi_dir="${DMI_TEST_DIR:-/sys/class/dmi/id}"
    UMPC_DETECTED=0; UMPC_VENDOR=""; UMPC_MODEL=""; UMPC_PANEL_ORIENTATION=""
    UMPC_VIDEO_CONNECTOR=""; UMPC_FBCON_ROTATE=""; UMPC_ALC287_QUIRK=0; UMPC_GPD_FAN=0

    local sys_vendor="" product_name="" board_name=""
    [[ -f "${dmi_dir}/sys_vendor" ]] && sys_vendor=$(cat "${dmi_dir}/sys_vendor" 2>/dev/null) || true
    [[ -f "${dmi_dir}/product_name" ]] && product_name=$(cat "${dmi_dir}/product_name" 2>/dev/null) || true
    [[ -f "${dmi_dir}/board_name" ]] && board_name=$(cat "${dmi_dir}/board_name" 2>/dev/null) || true

    if [[ "${sys_vendor}" == "GPD" ]]; then
        UMPC_VENDOR="GPD"
        case "${product_name}${board_name}" in
            *Pocket*4*|*G1628-04*)
                UMPC_DETECTED=1; UMPC_MODEL="Pocket 4"
                UMPC_PANEL_ORIENTATION="right_side_up"; UMPC_VIDEO_CONNECTOR="eDP-1"
                UMPC_FBCON_ROTATE="1"; UMPC_ALC287_QUIRK=1; UMPC_GPD_FAN=1 ;;
            *Pocket*3*|*G1618-03*)
                UMPC_DETECTED=1; UMPC_MODEL="Pocket 3"
                UMPC_PANEL_ORIENTATION="right_side_up"; UMPC_VIDEO_CONNECTOR="eDP-1"
                UMPC_FBCON_ROTATE="1"; UMPC_GPD_FAN=1 ;;
            *Win*Mini*|*G1617*)
                UMPC_DETECTED=1; UMPC_MODEL="Win Mini"; UMPC_GPD_FAN=1 ;;
            *Win*Max*2*|*G1619-04*|*G1619-05*)
                UMPC_DETECTED=1; UMPC_MODEL="Win Max 2"; UMPC_GPD_FAN=1 ;;
            *Win*4*|*G1618-04*)
                UMPC_DETECTED=1; UMPC_MODEL="Win 4"; UMPC_GPD_FAN=1 ;;
        esac
    fi
    if [[ "${sys_vendor}" == CHUWI* ]]; then
        case "${product_name}${board_name}" in
            *MiniBook*X*)
                UMPC_DETECTED=1; UMPC_VENDOR="CHUWI"; UMPC_MODEL="${product_name}"
                UMPC_PANEL_ORIENTATION="right_side_up"; UMPC_VIDEO_CONNECTOR="DSI-1"
                UMPC_FBCON_ROTATE="1" ;;
        esac
    fi
}

setup_fake_dmi() {
    local dir="$1" sys_vendor="$2" product_name="$3" board_name="${4:-}"
    rm -rf "${dir}"; mkdir -p "${dir}"
    printf '%s' "${sys_vendor}" > "${dir}/sys_vendor"
    printf '%s' "${product_name}" > "${dir}/product_name"
    [[ -n "${board_name}" ]] && printf '%s' "${board_name}" > "${dir}/board_name"
    return 0
}

# ============================================================================
echo "=== Test: UMPC CONFIG_VARS in constants ==="
declare -A wanted=( [UMPC_DETECTED]=0 [UMPC_VENDOR]=0 [UMPC_MODEL]=0
                    [UMPC_PANEL_ORIENTATION]=0 [UMPC_VIDEO_CONNECTOR]=0
                    [UMPC_FBCON_ROTATE]=0 [UMPC_ALC287_QUIRK]=0 [UMPC_GPD_FAN]=0 )
for var in "${CONFIG_VARS[@]}"; do
    [[ -v wanted[${var}] ]] && wanted[${var}]=1
done
for k in "${!wanted[@]}"; do
    assert_eq "${k} in CONFIG_VARS" "1" "${wanted[${k}]}"
done

echo ""
echo "=== Test: umpc_quirks checkpoint right after extras ==="
found_cp=0; order_ok=0; prev=""
for cp in "${CHECKPOINTS[@]}"; do
    [[ "${cp}" == "umpc_quirks" ]] && found_cp=1
    [[ "${prev}" == "extras" && "${cp}" == "umpc_quirks" ]] && order_ok=1
    prev="${cp}"
done
assert_eq "umpc_quirks in CHECKPOINTS" "1" "${found_cp}"
assert_eq "umpc_quirks comes right after extras" "1" "${order_ok}"

# ============================================================================
DMI_TEST_DIR="${MOUNTPOINT}/dmi"

echo ""
echo "=== Test: GPD Pocket 4 detection (G1628-04) ==="
setup_fake_dmi "${DMI_TEST_DIR}" "GPD" "G1628-04" "G1628-04"
test_detect_umpc
assert_eq "Pocket 4 detected"     "1"             "${UMPC_DETECTED}"
assert_eq "Pocket 4 vendor"       "GPD"           "${UMPC_VENDOR}"
assert_eq "Pocket 4 model"        "Pocket 4"      "${UMPC_MODEL}"
assert_eq "Pocket 4 panel"        "right_side_up" "${UMPC_PANEL_ORIENTATION}"
assert_eq "Pocket 4 connector"    "eDP-1"         "${UMPC_VIDEO_CONNECTOR}"
assert_eq "Pocket 4 fbcon"        "1"             "${UMPC_FBCON_ROTATE}"
assert_eq "Pocket 4 ALC287 quirk" "1"             "${UMPC_ALC287_QUIRK}"
assert_eq "Pocket 4 GPD fan note" "1"             "${UMPC_GPD_FAN}"

echo ""
echo "=== Test: GPD Win 4 (G1618-04, landscape — no rotation) ==="
setup_fake_dmi "${DMI_TEST_DIR}" "GPD" "G1618-04"
test_detect_umpc
assert_eq "Win 4 detected"        "1"             "${UMPC_DETECTED}"
assert_eq "Win 4 model"           "Win 4"         "${UMPC_MODEL}"
assert_eq "Win 4 no rotation"     ""              "${UMPC_PANEL_ORIENTATION}"
assert_eq "Win 4 GPD fan note"    "1"             "${UMPC_GPD_FAN}"
assert_eq "Win 4 no ALC287 quirk" "0"             "${UMPC_ALC287_QUIRK}"

echo ""
echo "=== Test: Chuwi MiniBook X detection (DSI-1) ==="
setup_fake_dmi "${DMI_TEST_DIR}" "CHUWI Innovation And Technology" "MiniBook X" "MiniBook X"
test_detect_umpc
assert_eq "MiniBook X detected"   "1"             "${UMPC_DETECTED}"
assert_eq "MiniBook X vendor"     "CHUWI"         "${UMPC_VENDOR}"
assert_eq "MiniBook X panel"      "right_side_up" "${UMPC_PANEL_ORIENTATION}"
assert_eq "MiniBook X connector"  "DSI-1"         "${UMPC_VIDEO_CONNECTOR}"
assert_eq "MiniBook X no GPD fan" "0"             "${UMPC_GPD_FAN}"

echo ""
echo "=== Test: non-UMPC vendor (should not detect) ==="
setup_fake_dmi "${DMI_TEST_DIR}" "Dell Inc." "XPS 13 9310"
test_detect_umpc
assert_eq "Dell XPS not detected" "0"             "${UMPC_DETECTED}"

# ============================================================================
echo ""
echo "=== Test: GRUB cmdline assembly (Pocket 4) ==="
UMPC_DETECTED=1; UMPC_PANEL_ORIENTATION="right_side_up"
UMPC_VIDEO_CONNECTOR="eDP-1"; UMPC_FBCON_ROTATE="1"
default_params="quiet"
if [[ "${UMPC_DETECTED:-0}" == "1" ]] && [[ -n "${UMPC_PANEL_ORIENTATION:-}" ]]; then
    default_params="${default_params} fbcon=rotate:${UMPC_FBCON_ROTATE} video=${UMPC_VIDEO_CONNECTOR}:panel_orientation=${UMPC_PANEL_ORIENTATION}"
fi
assert_eq "GRUB cmdline for Pocket 4" \
    "quiet fbcon=rotate:1 video=eDP-1:panel_orientation=right_side_up" \
    "${default_params}"

# ============================================================================
echo ""
echo "=== Test: umpc_apply_quirks no-op when not a UMPC ==="
rec_reset
UMPC_DETECTED=0
umpc_apply_quirks
rec_not "no chroot writes for non-UMPC" 'CHROOT:'

echo ""
echo "=== Test: umpc_apply_quirks for GPD Pocket 4 (ALC287 + fan + summary) ==="
rec_reset
UMPC_DETECTED=1; UMPC_VENDOR="GPD"; UMPC_MODEL="Pocket 4"
UMPC_PANEL_ORIENTATION="right_side_up"; UMPC_VIDEO_CONNECTOR="eDP-1"
UMPC_FBCON_ROTATE="1"; UMPC_ALC287_QUIRK=1; UMPC_GPD_FAN=1
umpc_apply_quirks
rec_has "writes alc287-unmute script"    'CHROOT: cat > /usr/local/sbin/alc287-unmute'
rec_has "chmod alc287-unmute script"     'CHROOT: chmod 0755 /usr/local/sbin/alc287-unmute'
rec_has "writes local.d start hook"      'CHROOT: cat > /etc/local.d/alc287-unmute.start'
rec_has "enables OpenRC local service"   'CHROOT: rc-update add local default'
rec_has "writes GPD fan POST-INSTALL"    'CHROOT: cat >> /root/POST-INSTALL-NOTES.txt'
rec_has "summary mentions ALC287"        'alc287-unmute service installed'
rec_not "no systemd unit (OpenRC only)"  'systemd/system/alc287'

echo ""
echo "=== Test: SDDM greeter rotation gated on /usr/share/sddm ==="
# chroot_exec mock returns 0 → 'test -d /usr/share/sddm' "succeeds" → rotate.
rec_reset
UMPC_DETECTED=1; UMPC_VENDOR="GPD"; UMPC_MODEL="Pocket 4"
UMPC_PANEL_ORIENTATION="right_side_up"; UMPC_VIDEO_CONNECTOR="eDP-1"
UMPC_FBCON_ROTATE="1"; UMPC_ALC287_QUIRK=0; UMPC_GPD_FAN=0
umpc_apply_quirks
rec_has "checks for SDDM presence"       'CHROOT: test -d /usr/share/sddm'
rec_has "installs xrandr via apk"        'APK: xrandr'
rec_has "writes SDDM Xsetup script"      'CHROOT: cat > /usr/share/sddm/scripts/Xsetup'

echo ""
echo "=== Test: Win 4 (landscape) — no panel rotation, no ALC287 ==="
rec_reset
UMPC_DETECTED=1; UMPC_VENDOR="GPD"; UMPC_MODEL="Win 4"
UMPC_PANEL_ORIENTATION=""; UMPC_VIDEO_CONNECTOR=""
UMPC_FBCON_ROTATE=""; UMPC_ALC287_QUIRK=0; UMPC_GPD_FAN=1
umpc_apply_quirks
rec_not "no SDDM rotation for landscape" 'CHROOT: cat > /usr/share/sddm/scripts/Xsetup'
rec_not "no ALC287 for Win 4"            'CHROOT: cat > /usr/local/sbin/alc287-unmute'
rec_has "still writes GPD fan note"      'CHROOT: cat >> /root/POST-INSTALL-NOTES.txt'

harness_report
