<!-- connect-migrate manifest v2 -->
<!-- result: safe-after-rewrites -->
<!-- generator: connect-migrate NORMALIZED -->
<!-- generated-at: NORMALIZED -->
<!-- project-root: schemas -->
<!-- files-scanned: 1 -->
<!-- directives-analyzed: 1 -->
<!-- divergent-sites: 3 -->
<!-- auto-fixes: 0 -->
<!-- no-ops: 3 -->
<!-- questions: 0 -->
<!-- upgrade: connect/v0.3 -> connect/v0.4 -->
<!-- parse-notices: 0 -->
<!-- schemas-skipped: 0 -->
<!-- already-at-target: false -->

# connect-migrate manifest — safe after rewrites

**Upgrade:** `connect/v0.3` (1 schema) → `connect/v0.4`

**Scope:** project root `schemas` · 1 `.graphql` file · 1 `@connect` directive analyzed.

Schemas considered: `flags.graphql`

Found 3 divergent token(s) — **every one is mechanically resolvable, with no developer decisions required.** Apply the rewrites below and the `connect/v0.4` upgrade is safe.

## Rewrites to apply (0)

None — no source edits are required.

## No action needed (3)

3 token(s) across 1 selection(s) parse differently under v0.4 but evaluate to the same value — a bare `null`/`true`/`false` that v0.3 resolved via response normalization. No edits required.

- `false` ×1
- `null` ×1
- `true` ×1

## Questions for the developer (0)

None — every divergence resolved mechanically. Clean bill of health.

## After applying — switch to `connect/v0.4`

Once the rewrites above are applied **and verified**, bump each migrated schema's connect `@link` to `connect/v0.4` as the **last** step — that's the version this manifest's diff targeted, and the one the rewrites make safe:

```graphql
@link(url: "https://specs.apollo.dev/connect/v0.4", import: ["@connect", "@source"])
```

Update the existing `@link(url: ".../connect/v0.n")` in place — keep each schema's other links (federation, etc.) untouched.

**Verify before this bump, not after.** Re-run `connect-migrate analyze` while the schema is *still* on its old `connect/v0.n` link and confirm zero divergent sites — that proves the fortifications took. Once the `@link` is on v0.4 the analyzer has nothing left to diff and reports `safe-to-upgrade` regardless, so a post-bump check can't tell a correct migration from one that skipped every fortification.
