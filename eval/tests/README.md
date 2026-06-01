# Analyzer golden tests

Deterministic, dependency-free snapshot tests for `connect-migrate analyze`.

Each case under `cases/<name>/` has:

- `schemas/*.graphql` — the input(s) the analyzer scans.
- `expected.md` — the committed, normalized manifest for that input.

The runner (`run.sh`) executes `connect-migrate analyze schemas` **from inside
each case dir**, so every manifest's `project-root` is the uniform relative path
`schemas`. It captures stdout only (the analyzer's one-line "scanned …" summary
goes to stderr and is ignored), normalizes the two non-deterministic header
lines, and diffs against `expected.md`.

Two header lines vary per run and are normalized to `NORMALIZED` before
comparison:

```
<!-- generated-at: … -->
<!-- generator: connect-migrate X.Y.Z -->
```

Everything else (result, counts, `site v2` block ids/offsets/`rewrite_to`, …) is
byte-stable for a given input.

## Running

```sh
make test          # from eval/: diff every case against its snapshot
./run.sh           # equivalent, run directly
UPDATE=1 ./run.sh  # refresh every expected.md from current analyzer output
```

`run.sh` prints `ok <name>` / `FAIL <name>` per case plus a summary, and exits
non-zero if any case fails.

## Snapshots are committed (and don't leak the eval answer)

The `expected.md` snapshots are committed on purpose — that's what makes these
tests reproducible. This does **not** leak the evaluation answer: `eval/tests/`
is never part of an agent's isolated work dir (the work dir is built from
`fixtures/` only), so the committed manifests here are invisible to a candidate
agent.
