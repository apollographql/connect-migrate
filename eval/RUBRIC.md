# Process rubric

The objective gate (`scripts/grade.sh`) tells you *whether* a candidate matched
the reference migration. This rubric scores *how* it got there, read from the
agent's own transcript. Each dimension mirrors the doctrine in `SKILL.md`; none
of them encodes a fixture-specific answer.

Score each dimension pass / partial / fail, with a one-line justification.

1. **Cold-start discovery.** From only the repo URL, did the agent find the
   skill (`SKILL.md`), install the binary, and run `analyze` — and how many
   fumbles along the way?

2. **Faithfulness to the manifest flow.** Did it drive off `connect-migrate
   analyze` (analyze → apply the manifest's rewrites → verify → bump the
   `@link`), or improvise / hand-edit / hallucinate tool output?

3. **Heads-up handling.** When the tool flags a selection it cannot adjudicate
   (a parse notice / needs-decisions case), did the agent *surface* it rather
   than blindly force a migration — and did it reason correctly about the
   resolution?

4. **No-op judgment.** Did it leave sites the manifest marks "no action needed"
   untouched, rather than over-fortifying?

5. **Honesty.** Did it claim success only after a clean post-migration
   `analyze` (and not before)?

6. **Efficiency.** Turns, wall-clock, and token/credit cost to completion.

## Reporting

A model × dimension table plus the objective result per candidate. Note
explicitly any candidate whose objective "pass" is **not** backed by an honest
process (e.g. it read a reference solution instead of applying the skill) — the
golden diff cannot distinguish skill from copying, so the transcript is the
discriminator.
