#!/usr/bin/env bash
# tests/test_system_services.sh — OpenRC runlevel + device-manager wiring.
#
# Regression guard for the #1 blocker: `apk --initdb alpine-base` does not
# populate /etc/runlevels, so system_finalize must enable the full stock set.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/_harness.sh
source "${SCRIPT_DIR}/_harness.sh"

harness_init
# shellcheck disable=SC1090
source "${LIB_DIR}/system.sh"
harness_mock

echo "=== Test: _setup_device_manager (desktop → eudev) ==="
rec_reset
DESKTOP_ENV="kde" _setup_device_manager
rec_has "installs eudev"                 'APK: eudev'
rec_has "enables udev (sysinit)"         'CHROOT: rc-update add udev sysinit'
rec_has "enables udev-trigger"           'CHROOT: rc-update add udev-trigger sysinit'
rec_has "enables udev-settle"            'CHROOT: rc-update add udev-settle sysinit'
rec_has "removes conflicting mdev"       'CHROOT: rc-update del mdev sysinit'
rec_not "does NOT enable mdev"           'CHROOT: rc-update add mdev sysinit'

echo ""
echo "=== Test: _setup_device_manager (headless → mdev) ==="
rec_reset
DESKTOP_ENV="none" _setup_device_manager
rec_has "enables mdev (headless)"        'CHROOT: rc-update add mdev sysinit'
rec_not "does NOT install eudev"         'APK: eudev'
rec_not "does NOT enable udev"           'CHROOT: rc-update add udev sysinit'

echo ""
echo "=== Test: system_finalize core runlevels (swap partition) ==="
rec_reset
DESKTOP_ENV="kde" SWAP_TYPE="partition" system_finalize
# sysinit
rec_has "sysinit: devfs"        'CHROOT: rc-update add devfs sysinit'
rec_has "sysinit: cgroups"      'CHROOT: rc-update add cgroups sysinit'
rec_has "sysinit: hwdrivers"    'CHROOT: rc-update add hwdrivers sysinit'
# boot — the ones that were missing before the fix
rec_has "boot: localmount"      'CHROOT: rc-update add localmount boot'
rec_has "boot: root"            'CHROOT: rc-update add root boot'
rec_has "boot: fsck"            'CHROOT: rc-update add fsck boot'
rec_has "boot: seedrng"         'CHROOT: rc-update add seedrng boot'
rec_has "boot: modules"         'CHROOT: rc-update add modules boot'
rec_has "boot: hostname"        'CHROOT: rc-update add hostname boot'
rec_has "boot: hwclock"         'CHROOT: rc-update add hwclock boot'
rec_has "boot: swap (partition)" 'CHROOT: rc-update add swap boot'
# default
rec_has "default: netmount"     'CHROOT: rc-update add netmount default'
rec_has "default: crond"        'CHROOT: rc-update add crond default'
# shutdown
rec_has "shutdown: killprocs"   'CHROOT: rc-update add killprocs shutdown'
# regressions: must NOT enable swclock alongside hwclock
rec_not "no swclock/hwclock conflict" 'CHROOT: rc-update add swclock boot'

echo ""
echo "=== Test: system_finalize without swap ==="
rec_reset
DESKTOP_ENV="none" SWAP_TYPE="none" system_finalize
rec_not "no swap service when SWAP_TYPE=none" 'CHROOT: rc-update add swap boot'
rec_has "still enables localmount"            'CHROOT: rc-update add localmount boot'

harness_report
