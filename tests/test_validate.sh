#!/usr/bin/env bash
# tests/test_validate.sh — validate_config enum guards for kernel/bootloader.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export _ALPINE_INSTALLER=1
export LIB_DIR="${SCRIPT_DIR}/lib"
export LOG_FILE="/tmp/alpine-test-validate-$$.log"
: > "${LOG_FILE}"

# shellcheck disable=SC1090
source "${LIB_DIR}/constants.sh"
# shellcheck disable=SC1090
source "${LIB_DIR}/logging.sh"
# shellcheck disable=SC1090
source "${LIB_DIR}/config.sh"

PASS=0
FAIL=0

# assert_err — run validate_config; assert its output contains/omits a pattern.
# $1 desc  $2 mode(has|not)  $3 regex
assert_err() {
    local desc="$1" mode="$2" pattern="$3" out
    out="$(validate_config 2>/dev/null || true)"
    if [[ "${mode}" == "has" ]]; then
        if grep -Eq -- "${pattern}" <<< "${out}"; then
            echo "  PASS: ${desc}"; (( PASS++ )) || true
        else
            echo "  FAIL: ${desc} — expected error matching: ${pattern}"; (( FAIL++ )) || true
        fi
    else
        if grep -Eq -- "${pattern}" <<< "${out}"; then
            echo "  FAIL: ${desc} — unexpected error: ${pattern}"; (( FAIL++ )) || true
        else
            echo "  PASS: ${desc}"; (( PASS++ )) || true
        fi
    fi
}

# Baseline: a config that is otherwise plausible. We only assert on the
# kernel/bootloader-specific messages, so unrelated errors are ignored.
TARGET_DISK="/dev/null" FILESYSTEM="ext4" HOSTNAME="alpine" TIMEZONE="UTC"
GPU_VENDOR="amd" USERNAME="u" ROOT_PASSWORD_HASH="x" USER_PASSWORD_HASH="y"
export TARGET_DISK FILESYSTEM HOSTNAME TIMEZONE GPU_VENDOR USERNAME \
    ROOT_PASSWORD_HASH USER_PASSWORD_HASH

echo "=== Test: KERNEL_TYPE enum ==="
KERNEL_TYPE="lts"  assert_err "lts accepted"  not 'KERNEL_TYPE='
KERNEL_TYPE="edge" assert_err "edge accepted" not 'KERNEL_TYPE='
KERNEL_TYPE="virt" assert_err "virt rejected" has 'KERNEL_TYPE=.*must be lts or edge'
export KERNEL_TYPE="lts"

echo ""
echo "=== Test: BOOTLOADER_TYPE enum ==="
BOOTLOADER_TYPE="grub"         assert_err "grub accepted"        not 'BOOTLOADER_TYPE='
BOOTLOADER_TYPE="systemd-boot" assert_err "systemd-boot rejected" has 'BOOTLOADER_TYPE=.*must be grub'

rm -f "${LOG_FILE}"
echo ""
echo "=== Results ==="
echo "Passed: ${PASS}"
echo "Failed: ${FAIL}"
[[ ${FAIL} -eq 0 ]] && exit 0 || exit 1
