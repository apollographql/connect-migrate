<!-- connect-migrate manifest v2 -->
<!-- result: safe-after-rewrites -->
<!-- generator: connect-migrate NORMALIZED -->
<!-- generated-at: NORMALIZED -->
<!-- project-root: schemas -->
<!-- files-scanned: 1 -->
<!-- directives-analyzed: 1 -->
<!-- divergent-sites: 2 -->
<!-- auto-fixes: 1 -->
<!-- no-ops: 1 -->
<!-- questions: 0 -->
<!-- upgrade: connect/v0.3 -> connect/v0.4 -->
<!-- parse-notices: 0 -->

# connect-migrate manifest — safe after rewrites

**Upgrade:** `connect/v0.3` (1 schema) → `connect/v0.4`

**Scope:** project root `schemas` · 1 `.graphql` file · 1 `@connect` directive analyzed.

Schemas considered: `pricing.graphql`

Found 2 divergent token(s) — **every one is mechanically resolvable, with no developer decisions required.** Apply the rewrites below and the `connect/v0.4` upgrade is safe.

## Rewrites to apply (1)

Deterministic `$.` fortifications. In v0.3 each of these was a field access; v0.4 silently rereads it as a literal, so fortifying preserves the original behavior. Apply each edit at the location in its machine block (`rewrite_to` is the exact replacement text for the `text` token).

<!-- connect-migrate site v2
  id: e8bb0f26
  file: pricing.graphql
  line: 8
  col: 5
  byte_offset: 297
  coordinate: Query.price
  from: connect/v0.3
  kind: key_quoted_flipped_to_literal_string
  text: "tier-code"
  source_range: 27..38
  followed_by: nothing
  recommendation: keep-v0.3
  rewrite_to: "$.\"tier-code\""
-->

- `tier-code` → `$."tier-code"` — `pricing.graphql:8` (`Query.price`)

This list is the source of truth for what gets applied. To **skip** a rewrite, delete its bullet and its `site v2` block above; to **change** a replacement, edit that block's `rewrite_to`. The agent applies exactly the blocks that remain, using each `rewrite_to` verbatim — nothing more.

## No action needed (1)

1 token(s) across 1 selection(s) parse differently under v0.4 but evaluate to the same value — a bare `null`/`true`/`false` that v0.3 resolved via response normalization. No edits required.

- `null` ×1

## Questions for the developer (0)

None — every divergence resolved mechanically. Clean bill of health.

## After applying — switch to `connect/v0.4`

Once the rewrites above are applied **and verified**, bump each migrated schema's connect `@link` to `connect/v0.4` as the **last** step — that's the version this manifest's diff targeted, and the one the rewrites make safe:

```graphql
@link(url: "https://specs.apollo.dev/connect/v0.4", import: ["@connect", "@source"])
```

Update the existing `@link(url: ".../connect/v0.n")` in place — keep each schema's other links (federation, etc.) untouched.

**Verify before this bump, not after.** Re-run `connect-migrate analyze` while the schema is *still* on its old `connect/v0.n` link and confirm zero divergent sites — that proves the fortifications took. Once the `@link` is on v0.4 the analyzer has nothing left to diff and reports `safe-to-upgrade` regardless, so a post-bump check can't tell a correct migration from one that skipped every fortification.
