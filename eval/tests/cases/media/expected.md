<!-- connect-migrate manifest v2 -->
<!-- result: safe-after-rewrites -->
<!-- generator: connect-migrate NORMALIZED -->
<!-- generated-at: NORMALIZED -->
<!-- project-root: schemas -->
<!-- files-scanned: 1 -->
<!-- directives-analyzed: 2 -->
<!-- divergent-sites: 4 -->
<!-- auto-fixes: 4 -->
<!-- no-ops: 0 -->
<!-- questions: 0 -->
<!-- upgrade: connect/v0.3 -> connect/v0.4 -->
<!-- parse-notices: 0 -->
<!-- schemas-skipped: 0 -->
<!-- already-at-target: false -->

# connect-migrate manifest — safe after rewrites

**Upgrade:** `connect/v0.3` (1 schema) → `connect/v0.4`

**Scope:** project root `schemas` · 1 `.graphql` file · 2 `@connect` directives analyzed.

Schemas considered: `media.graphql`

Found 4 divergent token(s) — **every one is mechanically resolvable, with no developer decisions required.** Apply the rewrites below and the `connect/v0.4` upgrade is safe.

## Rewrites to apply (4)

Deterministic `$.` fortifications. In v0.3 each of these was a field access; v0.4 silently rereads it as a literal, so fortifying preserves the original behavior. Apply each edit at the location in its machine block (`rewrite_to` is the exact replacement text for the `text` token).

<!-- connect-migrate site v2
  id: 8c8c61d6
  file: media.graphql
  line: 28
  col: 5
  byte_offset: 551
  coordinate: Query.book
  from: connect/v0.3
  kind: key_quoted_flipped_to_literal_string
  text: "author-name"
  source_range: 21..34
  followed_by: nothing
  recommendation: keep-v0.3
  rewrite_to: "$.\"author-name\""
-->
<!-- connect-migrate site v2
  id: 0bcfee3f
  file: media.graphql
  line: 28
  col: 5
  byte_offset: 551
  coordinate: Query.book
  from: connect/v0.3
  kind: key_quoted_flipped_to_literal_string
  text: "isbn-code"
  source_range: 45..56
  followed_by: nothing
  recommendation: keep-v0.3
  rewrite_to: "$.\"isbn-code\""
-->
<!-- connect-migrate site v2
  id: 7b11796e
  file: media.graphql
  line: 40
  col: 5
  byte_offset: 769
  coordinate: Query.film
  from: connect/v0.3
  kind: key_quoted_flipped_to_literal_string
  text: "director-name"
  source_range: 23..38
  followed_by: nothing
  recommendation: keep-v0.3
  rewrite_to: "$.\"director-name\""
-->
<!-- connect-migrate site v2
  id: 4ba919fb
  file: media.graphql
  line: 40
  col: 5
  byte_offset: 769
  coordinate: Query.film
  from: connect/v0.3
  kind: key_quoted_flipped_to_literal_string
  text: "release-year"
  source_range: 52..66
  followed_by: nothing
  recommendation: keep-v0.3
  rewrite_to: "$.\"release-year\""
-->

- `author-name` → `$."author-name"` — `media.graphql:28` (`Query.book`)
- `isbn-code` → `$."isbn-code"` — `media.graphql:28` (`Query.book`)
- `director-name` → `$."director-name"` — `media.graphql:40` (`Query.film`)
- `release-year` → `$."release-year"` — `media.graphql:40` (`Query.film`)

This list is the source of truth for what gets applied. To **skip** a rewrite, delete its bullet and its `site v2` block above; to **change** a replacement, edit that block's `rewrite_to`. The agent applies exactly the blocks that remain, using each `rewrite_to` verbatim — nothing more.

## No action needed (0)

None.

## Questions for the developer (0)

None — every divergence resolved mechanically. Clean bill of health.

## After applying — switch to `connect/v0.4`

Once the rewrites above are applied **and verified**, bump each migrated schema's connect `@link` to `connect/v0.4` as the **last** step — that's the version this manifest's diff targeted, and the one the rewrites make safe:

```graphql
@link(url: "https://specs.apollo.dev/connect/v0.4", import: ["@connect", "@source"])
```

Update the existing `@link(url: ".../connect/v0.n")` in place — keep each schema's other links (federation, etc.) untouched.

**Verify before this bump, not after.** Re-run `connect-migrate analyze` while the schema is *still* on its old `connect/v0.n` link and confirm zero divergent sites — that proves the fortifications took. Once the `@link` is on v0.4 the analyzer has nothing left to diff and reports `safe-to-upgrade` regardless, so a post-bump check can't tell a correct migration from one that skipped every fortification.
