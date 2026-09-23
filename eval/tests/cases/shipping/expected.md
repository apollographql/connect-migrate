<!-- connect-migrate manifest v2 -->
<!-- result: nothing-to-migrate -->
<!-- generator: connect-migrate NORMALIZED -->
<!-- generated-at: NORMALIZED -->
<!-- project-root: schemas -->
<!-- files-scanned: 1 -->
<!-- directives-analyzed: 0 -->
<!-- divergent-sites: 0 -->
<!-- auto-fixes: 0 -->
<!-- no-ops: 0 -->
<!-- questions: 0 -->
<!-- upgrade: connect/v0.2 -> connect/v0.4 -->
<!-- parse-notices: 1 -->
<!-- schemas-skipped: 0 -->
<!-- already-at-target: false -->

# connect-migrate report — no `@connect` directives present

**Scope:** project root `schemas` · 1 `.graphql` file · 0 `@connect` directives analyzed.

Schemas considered: `shipping.graphql`

## Heads up — selections not analyzed (1)

These `@connect` selections failed to parse under one or both specs, so they aren't in the buckets above. Non-fatal — the rest of the analysis stands — but review each:

- `Query.rate` (`shipping.graphql:7`): parses under `connect/v0.4` but **not** under the linked `connect/v0.2` — it uses syntax newer than the schema declares

No `@connect` selection parsed cleanly under both the linked spec and `connect/v0.4`, so there is nothing to migrate automatically — see the heads-up above and resolve those selections first.
