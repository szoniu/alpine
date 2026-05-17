#!/usr/bin/env bash
# tests/test_kernel_initramfs.sh — kernel selection + mkinitfs features.
#
# Guards: lts/edge mapping, btrfs/xfs unbootable-without-feature fix, initramfs
# filename matching the bootloader, firmware installed best-effort.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/_harness.sh
source "${SCRIPT_DIR}/_harness.sh"

harness_init
# shellcheck disable=SC1090
source "${LIB_DIR}/system.sh"
harness_mock

echo "=== Test: kernel package selection ==="
rec_reset
KERNEL_TYPE="lts" FILESYSTEM="ext4" LUKS_ENABLED="no" kernel_install
rec_has "lts → linux-lts"          'APK: linux-lts'
rec_has "firmware best-effort"     'APKOPT: linux-firmware'
rec_not "firmware not hard-installed (would fail phase)" 'APK: linux-firmware$'

rec_reset
KERNEL_TYPE="edge" FILESYSTEM="ext4" LUKS_ENABLED="no" kernel_install
rec_has "edge → linux-edge"        'APK: linux-edge'

rec_reset
KERNEL_TYPE="virt" FILESYSTEM="ext4" LUKS_ENABLED="no" kernel_install
rec_has "unknown type falls back to linux-lts" 'APK: linux-lts'
rec_not "no removed linux-virt"                'APK: linux-virt'

echo ""
echo "=== Test: mkinitfs features per filesystem ==="
rec_reset
KERNEL_TYPE="lts" FILESYSTEM="btrfs" LUKS_ENABLED="no" kernel_install
rec_has "btrfs feature present"    'features="[^"]*btrfs'
rec_has "initramfs named per flavor" 'mkinitfs -o /boot/initramfs-lts'

rec_reset
KERNEL_TYPE="lts" FILESYSTEM="xfs" LUKS_ENABLED="no" kernel_install
rec_has "xfs feature present"      'features="[^"]*xfs'

rec_reset
KERNEL_TYPE="lts" FILESYSTEM="ext4" LUKS_ENABLED="no" kernel_install
rec_has "ext4 feature present"     'features="[^"]*ext4'
rec_not "no btrfs for ext4 root"   'features="[^"]*btrfs'

echo ""
echo "=== Test: LUKS pulls cryptsetup + feature ==="
rec_reset
KERNEL_TYPE="lts" FILESYSTEM="ext4" LUKS_ENABLED="yes" kernel_install
rec_has "cryptsetup installed"     'APK: cryptsetup'
rec_has "cryptsetup mkinitfs feature" 'features="[^"]*cryptsetup'
rec_has "keymap feature for passphrase" 'features="[^"]*keymap'

harness_report
