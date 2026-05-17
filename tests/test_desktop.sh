#!/usr/bin/env bash
# tests/test_desktop.sh — desktop out-of-box wiring.
#
# Guards: fonts/polkit/elogind base, Xorg stack, seat management for wlroots
# compositors, NVIDIA without the non-existent mesa-vulkan-nouveau.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/_harness.sh
source "${SCRIPT_DIR}/_harness.sh"

harness_init
# shellcheck disable=SC1090
source "${LIB_DIR}/system.sh"      # system_set_locale
# shellcheck disable=SC1090
source "${LIB_DIR}/desktop.sh"
harness_mock

echo "=== Test: _install_common_desktop ==="
rec_reset
_install_common_desktop
rec_has "fonts installed"             'APK: .*font-dejavu'
rec_has "emoji font installed"        'APK: .*font-noto-emoji'
rec_has "polkit installed"            'APK: .*\bpolkit\b'
rec_has "elogind installed"           'APK: .*\belogind\b'
rec_has "elogind in BOOT runlevel"    'CHROOT: rc-update add elogind boot'
rec_not "elogind NOT in default"      'CHROOT: rc-update add elogind default'

echo ""
echo "=== Test: _install_xorg ==="
rec_reset
_install_xorg
rec_has "xorg-server installed"       'APK: .*xorg-server'
rec_has "libinput driver installed"   'APK: .*xf86-input-libinput'
rec_has "xwayland installed"          'APK: .*xwayland'

echo ""
echo "=== Test: _setup_greetd_seat (Sway) ==="
rec_reset
_setup_greetd_seat "sway"
rec_has "seatd installed"             'APK: .*\bseatd\b'
rec_has "seatd enabled"               'CHROOT: rc-update add seatd default'
rec_has "greetd installed"            'APK: .*\bgreetd\b'
rec_has "greetd enabled"              'CHROOT: rc-update add greetd default'
rec_has "greetd launches sway"        'agreety --cmd sway'
rec_has "greetd runs as greetd user"  'user = "greetd"'

rec_reset
_setup_greetd_seat "niri-session"
rec_has "greetd launches niri-session" 'agreety --cmd niri-session'

echo ""
echo "=== Test: NVIDIA driver (no mesa-vulkan-nouveau) ==="
rec_reset
_install_nvidia_open
rec_not "no non-existent mesa-vulkan-nouveau" 'mesa-vulkan-nouveau'
rec_has "swrast Vulkan fallback"      'APKOPT: mesa-vulkan-swrast'
rec_has "nvidia firmware best-effort" 'APKOPT: linux-firmware-nvidia'

echo ""
echo "=== Test: system_set_locale writes GUI locale files ==="
rec_reset
LOCALE="pl_PL.UTF-8" system_set_locale
rec_has "writes /etc/locale.conf"     'CHROOT: .*/etc/locale.conf'
rec_has "writes /etc/environment"     'CHROOT: .*/etc/environment'
rec_has "locale value propagated"     'LANG=pl_PL.UTF-8'

harness_report
