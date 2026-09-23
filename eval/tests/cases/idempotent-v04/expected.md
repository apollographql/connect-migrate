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
<!-- schemas-skipped: 0 -->
<!-- already-at-target: true -->

# connect-migrate manifest — safe to upgrade

**Upgrade:** `connect/v0.4` (1 schema). Every scanned schema already links `connect/v0.4` or newer, so there is nothing to migrate.

**Scope:** project root `schemas` · 1 `.graphql` file · 1 `@connect` directive analyzed.

Schemas considered: `widgets.graphql`

Every `@connect(selection: …)` across the schemas above was parsed at the spec its own schema links, and none of them diverges from the `connect/v0.4` grammar — zero divergent selections. This is a trustworthy verdict from the analyzer, not the absence of one.

No `@link` change is needed either: every scanned schema already declares `connect/v0.4` or newer. Leave them as they are.
