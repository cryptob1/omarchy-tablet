#!/bin/bash
# Runs every tests/test_*.sh. The gesture logic is pure functions; reading the
# touchscreen itself needs fingers on glass and is not covered here.
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
fail=0
for t in tests/test_*.sh; do
  out="$(bash "$t")"
  echo "$out"
  if grep -q '^  FAIL' <<<"$out"; then fail=1; fi
done
echo "---- $(grep -c '^  ok' <<<"$(for t in tests/test_*.sh; do bash "$t"; done)") passed"
exit $fail
