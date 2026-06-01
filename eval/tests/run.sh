#!/usr/bin/env bash
# Golden/snapshot test runner for `connect-migrate analyze`.
#
# For each case dir under cases/, runs the analyzer from inside the case dir as
# `connect-migrate analyze schemas` (so every manifest's project-root is the
# uniform relative path `schemas`), captures stdout only, normalizes the two
# non-deterministic header lines, and diffs against the committed expected.md.
#
#   ./run.sh            diff each case against its snapshot (default)
#   UPDATE=1 ./run.sh   (re)write each expected.md from current output
#
# Exits non-zero if any case fails (diff mode) or if the analyzer is missing.
set -u

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CASES_DIR="$TESTS_DIR/cases"

if ! command -v connect-migrate >/dev/null 2>&1; then
  echo "error: connect-migrate not found on PATH" >&2
  exit 2
fi

# Normalize the only two non-deterministic header lines. Everything else
# (result, counts, site-block ids/offsets/rewrite_to, …) is byte-stable.
normalize() {
  sed -E \
    -e 's|^<!-- generated-at:.*|<!-- generated-at: NORMALIZED -->|' \
    -e 's|^<!-- generator: connect-migrate .*|<!-- generator: connect-migrate NORMALIZED -->|'
}

pass=0
fail=0
failed_cases=()

for case_dir in "$CASES_DIR"/*/; do
  [ -d "$case_dir" ] || continue
  name="$(basename "$case_dir")"
  expected="$case_dir/expected.md"

  actual="$( cd "$case_dir" && connect-migrate analyze schemas 2>/dev/null | normalize )"

  if [ "${UPDATE:-}" = "1" ]; then
    printf '%s\n' "$actual" > "$expected"
    echo "updated $name"
    continue
  fi

  if [ ! -f "$expected" ]; then
    echo "FAIL $name (no expected.md — run UPDATE=1 ./run.sh)"
    fail=$((fail + 1))
    failed_cases+=("$name")
    continue
  fi

  if diff -u "$expected" <(printf '%s\n' "$actual") >/tmp/cm-golden-diff.$$ 2>&1; then
    echo "ok   $name"
    pass=$((pass + 1))
  else
    echo "FAIL $name"
    cat /tmp/cm-golden-diff.$$
    fail=$((fail + 1))
    failed_cases+=("$name")
  fi
  rm -f /tmp/cm-golden-diff.$$
done

if [ "${UPDATE:-}" = "1" ]; then
  echo "snapshots updated"
  exit 0
fi

echo
echo "summary: $pass passed, $fail failed"
if [ "$fail" -ne 0 ]; then
  echo "failed: ${failed_cases[*]}"
  exit 1
fi
exit 0
