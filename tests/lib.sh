#!/bin/bash
# Minimal dependency-free assert lib. Each test file defines test_* functions
# and sources this. run.sh discovers and runs them.
OMC_PASS=0
OMC_FAIL=0

_omc_ok()   { OMC_PASS=$((OMC_PASS+1)); echo "  ok   - $1"; }
_omc_bad()  { OMC_FAIL=$((OMC_FAIL+1)); echo "  FAIL - $1"; echo "         $2"; }

assert_eq() { # desc expected actual
  if [ "$2" = "$3" ]; then _omc_ok "$1"; else _omc_bad "$1" "expected [$2] got [$3]"; fi
}
assert_contains() { # desc haystack needle
  case "$2" in *"$3"*) _omc_ok "$1";; *) _omc_bad "$1" "[$2] does not contain [$3]";; esac
}
assert_not_contains() { # desc haystack needle
  case "$2" in *"$3"*) _omc_bad "$1" "[$2] unexpectedly contains [$3]";; *) _omc_ok "$1";; esac
}
assert_exit() { # desc expected_code actual_code
  if [ "$2" = "$3" ]; then _omc_ok "$1"; else _omc_bad "$1" "expected exit $2 got $3"; fi
}
