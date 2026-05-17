#!/usr/bin/env bash
# tests/_harness.sh — Shared mock harness for unit-testing lib/ functions.
#
# The installer's lib/ functions are side-effecting: they run commands inside a
# chroot via chroot_exec / apk_install / try. To test their *logic* without a
# real Alpine target we stub those primitives so every command they would run
# is recorded to $REC, then assert on the recording.
#
# Usage:
#   source "$(dirname "${BASH_SOURCE[0]}")/_harness.sh"
#   harness_init                 # sets up env + REC, sources constants.sh
#   source "${LIB_DIR}/system.sh"
#   harness_mock                 # install stubs (after sourcing the module)
#   <call function under test>
#   rec_has  'CHROOT: rc-update add localmount boot'
#   rec_not  'CHROOT: rc-update add swclock boot'
#   harness_report               # prints PASS/FAIL summary, sets exit status

set -uo pipefail

PASS=0
FAIL=0
REC=""

# --- assertions -------------------------------------------------------------

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "${expected}" == "${actual}" ]]; then
        echo "  PASS: ${desc}"
        (( PASS++ )) || true
    else
        echo "  FAIL: ${desc} — expected '${expected}', got '${actual}'"
        (( FAIL++ )) || true
    fi
}

# rec_has — assert the recording contains a line matching the given regex.
rec_has() {
    local desc="$1" pattern="$2"
    if grep -Eq -- "${pattern}" "${REC}"; then
        echo "  PASS: ${desc}"
        (( PASS++ )) || true
    else
        echo "  FAIL: ${desc} — no recorded line matched: ${pattern}"
        (( FAIL++ )) || true
    fi
}

# rec_not — assert the recording does NOT contain a matching line.
rec_not() {
    local desc="$1" pattern="$2"
    if grep -Eq -- "${pattern}" "${REC}"; then
        echo "  FAIL: ${desc} — unexpectedly recorded: ${pattern}"
        (( FAIL++ )) || true
    else
        echo "  PASS: ${desc}"
        (( PASS++ )) || true
    fi
}

rec_reset() { : > "${REC}"; }

# --- environment ------------------------------------------------------------

harness_init() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[1]}")/.." && pwd)"

    export _ALPINE_INSTALLER=1
    export LIB_DIR="${script_dir}/lib"
    export DATA_DIR=""                       # disables gum extraction branch
    export LOG_FILE="/tmp/alpine-test-$$.log"
    export MOUNTPOINT
    MOUNTPOINT="$(mktemp -d)"
    : > "${LOG_FILE}"

    REC="$(mktemp)"

    # Constants use `: "${VAR:=default}"`, so anything exported above wins.
    # shellcheck disable=SC1090
    source "${LIB_DIR}/constants.sh"
}

# harness_mock — override every side-effecting primitive with a recorder.
# Call AFTER sourcing the module under test so these definitions win.
harness_mock() {
    chroot_exec() { printf 'CHROOT: %s\n' "$*" >> "${REC}"; return 0; }

    # apk_install "description" pkg...   → record the package list
    apk_install() { local _d="$1"; shift; printf 'APK: %s\n' "$*" >> "${REC}"; return 0; }
    apk_install_if_available() { printf 'APKOPT: %s\n' "$1" >> "${REC}"; return 0; }

    # try "description" cmd args...      → run the wrapped command (a stub)
    try() { local _d="$1"; shift; "$@"; }

    enable_community_repo() { printf 'COMMUNITY_REPO\n' >> "${REC}"; return 0; }
    enable_testing_repo()   { printf 'TESTING_REPO\n'   >> "${REC}"; return 0; }
    get_microcode_package() { echo ""; }
    maybe_exec() { :; }

    einfo()  { :; }
    ewarn()  { :; }
    eerror() { :; }
    elog()   { :; }
    die()    { printf 'DIE: %s\n' "$*" >> "${REC}"; return 1; }
}

harness_cleanup() {
    rm -f "${LOG_FILE}" "${REC}" 2>/dev/null || true
    [[ -n "${MOUNTPOINT:-}" && "${MOUNTPOINT}" == /tmp/* ]] && rm -rf "${MOUNTPOINT}" 2>/dev/null || true
}

harness_report() {
    harness_cleanup
    echo ""
    echo "=== Results ==="
    echo "Passed: ${PASS}"
    echo "Failed: ${FAIL}"
    [[ ${FAIL} -eq 0 ]] && exit 0 || exit 1
}
