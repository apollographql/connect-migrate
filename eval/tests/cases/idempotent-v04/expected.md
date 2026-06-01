<!-- connect-migrate manifest v2 -->
<!-- result: safe-to-upgrade -->
<!-- generator: connect-migrate NORMALIZED -->
<!-- generated-at: NORMALIZED -->
<!-- project-root: schemas -->
<!-- files-scanned: 1 -->
<!-- directives-analyzed: 1 -->
<!-- divergent-sites: 0 -->
<!-- auto-fixes: 0 -->
<!-- no-ops: 0 -->
<!-- questions: 0 -->
<!-- upgrade: connect/v0.4 -> connect/v0.4 -->
<!-- parse-notices: 0 -->

# connect-migrate manifest — safe to upgrade

**Upgrade:** `connect/v0.4` (1 schema) → `connect/v0.4`

**Scope:** project root `schemas` · 1 `.graphql` file · 1 `@connect` directive analyzed.

Schemas considered: `widgets.graphql`

Every `@connect(selection: …)` across the schemas above parses identically under `connect/v0.3` and `connect/v0.4` — zero divergent selections. This is a trustworthy verdict from the analyzer, not the absence of one: the upgrade is safe with no source changes.

Update your schema's `@link` to `connect/v0.4` whenever you're ready:

```graphql
extend schema
  @link(url: "https://specs.apollo.dev/connect/v0.4", import: ["@connect", "@source"])
```
