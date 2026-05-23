#!/usr/bin/env bash
# Aggregator for /update-plugins unit tests.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TESTS=( "$SCRIPT_DIR"/0[1-8]-*.sh )

pass=0
fail=0
failed_tests=()

for t in "${TESTS[@]}"; do
    name="$(basename "$t")"
    if bash "$t" >/dev/null 2>&1; then
        printf '  PASS  %s\n' "$name"
        pass=$((pass + 1))
    else
        printf '  FAIL  %s\n' "$name"
        fail=$((fail + 1))
        failed_tests+=( "$name" )
    fi
done

total=$((pass + fail))
printf '\n%d passed, %d failed of %d total\n' "$pass" "$fail" "$total"

if [ "$fail" -gt 0 ]; then
    printf '\nFailed tests:\n'
    for f in "${failed_tests[@]}"; do printf '  %s\n' "$f"; done
    exit 1
fi
exit 0
