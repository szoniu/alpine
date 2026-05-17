#!/usr/bin/env bash
# tests/test_networking.sh — install_networking: dbus + NM Wi-Fi backend.
#
# Guards: dbus (NM/elogind/polkit hard dep) installed+enabled regardless of
# desktop; networkmanager-openrc (init script) and Wi-Fi backend present.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/_harness.sh
source "${SCRIPT_DIR}/_harness.sh"

harness_init
# shellcheck disable=SC1090
source "${LIB_DIR}/system.sh"
harness_mock

echo "=== Test: install_networking ==="
rec_reset
install_networking
rec_has "dbus installed"                 'APK: .*\bdbus\b'
rec_has "dbus-openrc init script"        'APK: .*dbus-openrc'
rec_has "dbus enabled"                   'CHROOT: rc-update add dbus default'
rec_has "networkmanager installed"       'APK: .*\bnetworkmanager\b'
rec_has "networkmanager-openrc present"  'APK: .*networkmanager-openrc'
rec_has "Wi-Fi backend present"          'APK: .*networkmanager-wifi'
rec_has "wpa_supplicant present"         'APK: .*wpa_supplicant'
rec_has "NetworkManager enabled"         'CHROOT: rc-update add networkmanager default'
rec_has "loopback via networking (boot)" 'CHROOT: rc-update add networking boot'
rec_has "writes /etc/network/interfaces" 'CHROOT: cat > /etc/network/interfaces'
rec_has "lo configured in interfaces"    '^iface lo inet loopback$'

harness_report
