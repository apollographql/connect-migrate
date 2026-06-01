#!/usr/bin/env bash
#
# grade.sh — objective grade of one candidate migration.
#
# Two gates (see README.md → "Scoring"):
#   1. Tool gate (necessary, NOT sufficient): `connect-migrate analyze` on the
#      candidate must report result=safe-to-upgrade, divergent-sites=0,
#      parse-notices=0.
#   2. Authoritative gate: the candidate's schemas must byte-match the expected
#      ("golden") migration. `analyze` alone false-passes a migration that bumps
#      the @link but skips the selection fortifications, so the diff is decisive.
#
# The expected directory is supplied at grade time and is deliberately NOT part
# of this repo (it is the reference solution — keeping it here would leak the
# answer to the agents, who read this repo). See README.md.
#
# Usage: grade.sh <candidate-dir> <expected-dir>
#   <candidate-dir>/schemas  the agent's migrated schemas
#   <expected-dir>           reference migrated schemas (private)
#
set -euo pipefail

cand="${1:?usage: grade.sh <candidate-dir> <expected-dir>}"
expected="${2:?usage: grade.sh <candidate-dir> <expected-dir>}"
schemas="$cand/schemas"

[ -d "$schemas" ]   || { echo "grade: no schemas/ under $cand" >&2; exit 2; }
[ -d "$expected" ]  || { echo "grade: expected dir not found: $expected" >&2; exit 2; }

analyze="$(connect-migrate analyze "$schemas" 2>&1 || true)"
field() { printf '%s\n' "$analyze" | grep -oE "$1: [A-Za-z0-9-]+" | head -1 | awk '{print $2}'; }
result="$(field 'result')"
divergent="$(field 'divergent-sites')"
notices="$(field 'parse-notices')"

if diff -ru "$expected" "$schemas" >/tmp/grade-diff.$$ 2>&1; then
  diffstatus="match"
else
  diffstatus="differs"
fi

pass=false
if [ "$result" = "safe-to-upgrade" ] && [ "$divergent" = "0" ] \
   && [ "$notices" = "0" ] && [ "$diffstatus" = "match" ]; then
  pass=true
fi

# Machine-readable result (so the objective layer can feed CI unchanged).
cat <<JSON
{
  "candidate": "$cand",
  "analyze": { "result": "${result:-unknown}", "divergent_sites": "${divergent:-?}", "parse_notices": "${notices:-?}" },
  "golden_diff": "$diffstatus",
  "pass": $pass
}
JSON

if [ "$diffstatus" = "differs" ]; then
  echo "--- diff vs expected (candidate is +) ---" >&2
  cat /tmp/grade-diff.$$ >&2
fi
rm -f /tmp/grade-diff.$$

[ "$pass" = true ]
