#!/usr/bin/env bash
# tests/run_all.sh — Run every test_*.sh plus shellcheck. Non-zero on any fail.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fail=0

for t in "${SCRIPT_DIR}"/test_*.sh; do
    echo ""
    echo "########################################"
    echo "# ${t##*/}"
    echo "########################################"
    bash "${t}" || { fail=1; echo ">>> ${t##*/} FAILED"; }
done

echo ""
echo "########################################"
echo "# shellcheck.sh"
echo "########################################"
bash "${SCRIPT_DIR}/shellcheck.sh" || fail=1

echo ""
if [[ ${fail} -eq 0 ]]; then
    echo "ALL TESTS PASSED"
else
    echo "SOME TESTS FAILED"
fi
exit ${fail}
