# connect-migrate evaluation harness

A small, dependency-free harness for evaluating how well a coding agent can
discover and apply this project's migration skill **cold** — given only the
repo URL, can it migrate a set of connector schemas to `connect/v0.4`?

It is deliberately DIY (no eval framework) but follows conventional structure so
it is easy to read, run, and extend.

## Layout

```
eval/
  README.md            this file
  prompt.txt           the exact cold prompt handed to each agent (verbatim)
  RUBRIC.md            the 6-dimension process rubric (human-judged)
  fixtures/            seed (pre-migration) schemas — the agent's starting input
  scripts/
    make-workdir.sh    fixtures/ -> an isolated single-commit git repo for one agent
    grade.sh           objective grade: analyze + diff against a reference migration
  Makefile             make workdir / make grade
```

## Prerequisites

- `connect-migrate` on `PATH` (`./install.sh` from the repo root).
- `git`, `make`, a POSIX shell.

## Running an evaluation

1. **Build an isolated work dir** for each agent:
   ```
   make workdir DIR=/tmp/eval/agent-a
   ```
   This copies `fixtures/` into `DIR/schemas/` and commits them as the *single*
   commit of a fresh repo (no migration history, no remotes).

2. **Hand the agent that directory and `prompt.txt` verbatim.** Give every agent
   the identical prompt; if an agent asks the developer a question, answer it
   the same way for all (keep a fixed answer key — see "Integrity" for why it
   lives outside this repo). Do not coach toward the migration.

3. **Grade** once the agent reports done:
   ```
   make grade DIR=/tmp/eval/agent-a EXPECTED=/path/to/reference-migration
   ```
   `EXPECTED` is the reference ("golden") migrated schemas, supplied at grade
   time (see "Integrity"). `grade.sh` prints a machine-readable result and exits
   non-zero on fail.

4. **Score the process** from the agent's transcript using `RUBRIC.md`.

## Scoring

Two layers:

- **Objective (automated, `grade.sh`).** Two gates:
  1. *Tool gate (necessary, not sufficient):* `connect-migrate analyze` on the
     result reports `safe-to-upgrade`, `divergent-sites: 0`, `parse-notices: 0`.
  2. *Authoritative gate:* the schemas byte-match `EXPECTED`.

  The diff is decisive because the tool gate **false-passes** an incomplete
  migration: once a schema's `@link` is on `connect/v0.4`, `analyze` has nothing
  left to compare and returns `safe-to-upgrade` even if the selection rewrites
  were skipped. (This is also why `SKILL.md` says to verify *before* bumping the
  link.)

- **Process (human-judged, `RUBRIC.md`).** Discovery, faithfulness to the
  manifest flow, heads-up handling, no-op judgment, honesty, efficiency.

## Integrity invariants

The eval is only meaningful if the agent cannot read the answer. Two distinct
leak vectors, both must stay closed:

1. **Git history.** Agents get an **isolated, single-commit** repo from
   `make-workdir.sh` — never a `git worktree` of, or a clone with refs to, a
   repo that contains the migrated result. Otherwise `git log --all` /
   `git show <ref>` exposes a prior correct migration. `make-workdir.sh` asserts
   exactly one commit and no remotes.

2. **Co-located answer files.** The reference migration (`EXPECTED`), any answer
   key, and per-fixture expected-outcome specs are **not** committed to this
   repo — agents are pointed *here* to read `SKILL.md`, so anything answer-
   bearing in the tree is the most direct leak possible. Keep those artifacts in
   a separate private location and pass them in only at grade time. `.gitignore`
   blocks the common paths (`expected/`, `golden/`, `results/`, …).

The reference migration is itself a *solution* to the task (this tool has no
`apply` subcommand by design — applying is the agent's job), so treat it like an
answer key: generate it with a trusted reference procedure kept outside this
repo, and never let it enter an agent's working tree or history.
