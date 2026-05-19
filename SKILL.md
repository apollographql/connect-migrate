# Apollo Connectors `connect/v0.3` → `connect/v0.4` migration skill

You are helping a developer upgrade an Apollo Connectors–enabled
supergraph from `@link(url: "https://specs.apollo.dev/connect/v0.3")`
to `connect/v0.4`. The [SubSelection/LitObject grammar
unification](https://github.com/apollographql/router/pull/9261) in v0.4
changes how a small but important class of `@connect(selection: …)`
expressions parse. The numbers across a 7,375-supergraph customer
corpus:

- 97.4% of `@connect(selection: …)` strings parse identically in v0.3
  and v0.4 — no migration needed.
- 2.1% have at least one site where the v0.4 reading differs from v0.3.
- The large majority of those differing sites (~77%) are
  **placeholder-literal patterns** (`field: null`, `field: true`,
  `field: "USD"`) where the v0.4 reading is almost certainly what the
  developer originally meant. In v0.3 the parser tried to look up a
  *field* named `null` / `true` / `"USD"` in the upstream response,
  didn't find it, and returned `None` — which GraphQL's response
  normalization then surfaced as `null`. The intent (a literal value)
  matched the observed output (a null) by accident. v0.4 makes that
  intent explicit and reliable. Upgrading is the fix.
- A meaningful minority (~22%) are **quoted field-name references**
  for REST APIs whose field names aren't valid GraphQL identifiers
  (`gqlSafeAlias: "@odata.nextLink"`, `score: "@search.score"`,
  `id: "@id"`). These need a small source change to preserve their v0.3
  meaning under v0.4.

A blind migration script can preserve v0.3 behavior everywhere, but
doing so would forfeit the placeholder-literal wins. The job of this
skill is to walk the affected sites with the developer (or have an
agent walk them on the developer's behalf), making the *intent* call
per site.

This skill is designed for a two-step flow:

1. **Analyze** the project, producing a single human-editable
   `recommendations.md` file with one entry per site that needs a
   decision. The developer (or a second agent) edits the file to
   confirm or override each recommendation.
2. **Apply** the edited file: read each `Decision:`, perform the
   chosen source edits, then re-verify that no unintended divergence
   remains.

Either step can be driven by a human directly, but the two-step shape
exists so that you (the agent) and the developer collaborate at the
single point where judgment is actually required: reviewing the
decisions file.

---

## Prerequisite: install `connect-migrate`

The CLI lives at <https://github.com/apollographql/connect-migrate>.
On macOS and Linux:

```sh
curl -fsSL https://raw.githubusercontent.com/apollographql/connect-migrate/main/install.sh | sh
```

Verify with `connect-migrate --version`. If the install fails, see the
repo README for fallback instructions (Windows users download the
binary manually).

---

## Mode A — Analyze: produce `recommendations.md`

Use this mode when no `recommendations.md` exists yet (or the developer
explicitly asks for a fresh analysis).

### Step A1: run the analyzer

From the project root (the directory containing the developer's
subgraph schemas, supergraph config, or composed supergraph SDL):

```sh
connect-migrate analyze . > recommendations.md
```

`connect-migrate analyze` walks `.graphql` files, finds every
`@connect(selection: …)` directive, dual-parses each selection under
v0.3 and v0.4 grammars, and writes the differing sites to stdout in
the recommendations format. Sites that parse identically under both
grammars are **not** emitted — they need no migration.

Pipe to whatever sink fits — a file (above), `less`, a clipboard
utility — or pass `-o`/`--output` to have analyze write the file
itself:

```sh
connect-migrate analyze subgraphs/billing subgraphs/orders \
  -o recommendations.md
```

### Step A2: triage each token (you are the analyzer here)

For every divergent token within a section, the analyzer classifies it
into one of two buckets. The classification drives **two** things:

1. Whether the token's text gets a `$.` prefix in the section's
   pre-filled Proposed rewrite block.
2. The default state of the section-level checklist — `apply the
   rewrite above` is pre-checked iff at least one token in the
   section was classified `keep-v0.3`.

The developer can override either default. The triage rules:

#### Keep-v0.3 — Almost certainly a field reference

The v0.3 reading was intentional and the v0.4 literal reading is
wrong. The token gets `$.` prepended in the rewrite block. Heuristics:

- Quoted string with characters that aren't valid in a GraphQL bare
  identifier (`@`, `:`, `/`, `-`, `.`, spaces). Real examples from the
  corpus: `"@odata.nextLink"`, `"@odata.count"`, `"@type"`, `"@id"`,
  `"@search.score"`, `"prism:url"`, `"dc:identifier"`,
  `"opensearch:totalResults"`, `"Cntl_LockSeq"`.
- Quoted string that looks like a REST API field name (camelCase or
  snake_case): `"refresh_token_expires_in"`, `"developer.email"`.
- `followed_by` is anything other than `nothing` — particularly
  `sub_selection` (literals don't have sub-fields, so this is
  unambiguous; the parser-level fix in commit `bee6b0032` already
  handles this case, but legacy schemas may still surface it).

Rewrite shape: `"@odata.nextLink"` → `$."@odata.nextLink"`; bare
`null`/`true`/`false` → `$.null` / `$.true` / `$.false`.

#### Embrace-v0.4 — Almost certainly a literal

The v0.4 reading is what the developer wanted all along; the v0.3
behavior was silently broken. The token is left unchanged in the
rewrite block. Heuristics:

- Bare `null` / `true` / `false`. The corpus shows these are almost
  always intended as placeholder values — `description: null`,
  `success: true`. In v0.3 the parser tried to look up a field named
  `null`/`true`/`false` in the upstream response, didn't find it,
  returned `None`, and GraphQL's response normalization surfaced that
  as `null` — accidentally matching the literal-intent the developer
  expressed. v0.4 makes the intent explicit and removes the dependence
  on that incidental normalization.
- Short uppercase constants: `"USD"`, `"USA"`, `"PASSENGER"`.
- Currency-like or formatting tokens: `"0.00"`, `"-"`, `"2x"`.
- Single-character placeholders.

If every token in the section falls into this bucket, the section's
Proposed rewrite equals the original selection and the checklist
defaults to `leave the source unchanged`.

#### What about ambiguous tokens?

Sections with at least one ambiguous token still default to
`apply the rewrite above` with the safest fortification pre-applied
(the v0.3 reading is preserved). The reasoning bullet under the
Original selection should note the ambiguity so the developer knows
to inspect the rewrite. If they accept v0.4 for the ambiguous token,
they edit that line of the rewrite block back to the original form.

### Step A3: write `recommendations.md`

`connect-migrate analyze` produces the file. You don't author it by
hand — but you do need to know the format because Mode B reads it
back, and because the developer may ask why a particular section is
shaped the way it is.

See the [Recommendations format](#recommendations-format) section
below for the spec and a worked example.

### Step A4: hand off

Tell the developer the file is ready and what they should look for:

> I've written `recommendations.md` with N sections covering K
> divergent `@connect` tokens. Each section has a Proposed rewrite
> block pre-filled with my recommendation and a two-option checklist
> below it. Edit the rewrite block if you want a different
> replacement, flip the checkbox if you want to leave the source
> unchanged instead, then run `connect-migrate apply recommendations.md`
> (or ask me to run it).

Do not run `apply` automatically. The whole point of the two-step flow
is that the developer reviews the file first.

---

## Mode B — Apply: consume an edited `recommendations.md`

Use this mode when a `recommendations.md` exists and the developer
asks you to apply it (or says they're done editing).

### Step B1: dry-run first

```sh
connect-migrate apply recommendations.md --dry-run
```

`--dry-run` prints the unified diff that `apply` would produce, but
writes nothing. Show the diff to the developer and ask for go-ahead
before writing.

If `--dry-run` reports any of the following, stop and surface them to
the developer:

- **No checkbox checked, or both checked** — every section must have
  exactly one of `[x] apply the rewrite above` or `[x] leave the
  source unchanged`. Apply refuses to act on ambiguous sections.
- **Rewrite block is empty when `apply the rewrite above` is checked**
  — the developer accidentally cleared the block. Apply refuses.
- **Stale section identifier** — the source file the recommendation
  refers to has been edited and the section's content hash no longer
  matches. Re-run `connect-migrate analyze` to regenerate the file,
  then re-apply the developer's prior decisions.
  <!-- FOLLOW-UP: future versions may auto-refresh by re-running
       analyze under the hood and three-way-merging the developer's
       checklist + rewrite edits onto the fresh sections. For now,
       prompt the developer to re-run analyze themselves. -->

### Step B2: apply for real

Once the dry-run looks right:

```sh
connect-migrate apply recommendations.md
```

This writes the source edits. `recommendations.md` is updated in
place with a `**Status:**` line on each section (`applied` /
`unchanged`) so it remains a durable record of what happened.

### Step B3: verify

`apply` automatically re-runs `analyze` after writing edits and
reports the result. If any section the developer marked `apply the
rewrite above` still shows up as divergent, that's a bug — surface it
to the developer and don't claim success.

Manual final sanity checks worth doing:

- Run `cargo check` (or `npm run check`, or the project's
  equivalent) — the source edits are syntactic only; they shouldn't
  affect typechecking, but a green build is reassurance.
- Spot-check 1–2 representative selections against real backend
  responses if a sandbox is available.

---

## Recommendations format

`connect-migrate analyze` writes a single markdown file with one
section per `@connect(selection: …)` directive that contains at least
one divergent token. The format is versioned via the leading
`<!-- connect-migrate recommendations v1 -->` comment; `apply` refuses
to run against a file whose version it doesn't recognize.

### Document structure (worked example)

````````markdown
<!-- connect-migrate recommendations v1 -->
<!-- generator: connect-migrate 0.X.Y -->
<!-- generated-at: 2026-05-19T14:28:18Z -->
<!-- project-root: . -->

# `connect/v0.3` → `connect/v0.4` migration recommendations

2 section(s) need a decision (5 divergent token(s) across 2 `@connect`
selection(s)). For each section, edit the **Proposed rewrite** block
as needed and check the box that reflects your decision, then run:

    connect-migrate apply recommendations.md

Each section has two decision options. **Exactly one must be checked.**
The defaults reflect what the analyzer recommends; edit the Proposed
rewrite block, flip the checkbox, or both.

- **apply the rewrite above** — apply uses the contents of the
  Proposed rewrite block as the new selection.
- **leave the source unchanged** — apply makes no change (accept the
  v0.4 literal reading).

---

## section 1 of 2 — `subgraphs/billing/connector.graphql` (`Invoice.partner`)

<!-- connect-migrate site v1
  id: fa3c7e92
  file: subgraphs/billing/connector.graphql
  line: 42
  col: 17
  coordinate: Invoice.partner
  kind: key_quoted_flipped_to_literal_string
  text: "sold-to"
  followed_by: nothing
  recommendation: keep-v0.3
-->
<!-- connect-migrate site v1
  id: 7b22a014
  file: subgraphs/billing/connector.graphql
  line: 42
  col: 17
  coordinate: Invoice.partner
  kind: key_quoted_flipped_to_literal_string
  text: "bill-to"
  followed_by: nothing
  recommendation: keep-v0.3
-->

**Original selection:**

```graphql
soldTo: "sold-to"
billTo: "bill-to"
```

- `"sold-to"` contains characters not valid in a GraphQL identifier,
  so it is almost certainly a quoted field name from a REST response.
- `"bill-to"` contains characters not valid in a GraphQL identifier,
  so it is almost certainly a quoted field name from a REST response.

**Proposed rewrite** (edit if needed):

```graphql
soldTo: $."sold-to"
billTo: $."bill-to"
```

**Decide:**
- [x] apply the rewrite above
- [ ] leave the source unchanged

---

## section 2 of 2 — `subgraphs/billing/connector.graphql` (`Invoice.status`)

<!-- connect-migrate site v1
  id: 5454cd79
  ...
  text: "null"
  recommendation: embrace-v0.4
-->

**Original selection:**

```graphql
status: null
```

- Bare `null` in value position is almost always intended as a literal
  null value; v0.3 returned the same thing accidentally via response
  normalization.

**Proposed rewrite** (edit if needed):

```graphql
status: null
```

**Decide:**
- [ ] apply the rewrite above
- [x] leave the source unchanged
````````

### Per-site identity comments

The HTML comment block at the top of each section is the
machine-readable identity. There is one comment per divergent token
within the section. `apply` parses these; everything else (reasoning
bullets, prose) is free-form markdown.

| Field             | Notes |
|-------------------|-------|
| `id`              | Stable 8-hex content-hash of the site. Survives line shifts in the source file. |
| `file`            | Path relative to `project-root`. |
| `line`, `col`     | Position at analyze time. Approximate (`@connect` directive start); apply re-locates by text match. |
| `coordinate`      | GraphQL schema coordinate (`Type.field`). |
| `kind`            | One of: `key_quoted_flipped_to_literal_string`, `key_flipped_to_literal_null`, `key_flipped_to_literal_bool`, `key_field_flipped_to_literal_string`. |
| `text`            | The literal source text of the token (HTML-comment-escaped). |
| `followed_by`     | One of: `nothing`, `sub_selection`, `key_access`, `method`, `question`. |
| `recommendation`  | The analyzer's per-token guess: `keep-v0.3` or `embrace-v0.4`. |

### Decision checklist

A section's `**Decide:**` block is the editable part. The two options
appear as markdown checkboxes:

```markdown
**Decide:**
- [x] apply the rewrite above
- [ ] leave the source unchanged
```

`apply` matches by position: the first `- [x]` (or `- [X]`) line means
"apply the rewrite," the second means "leave alone." Exactly one must
be checked.

### Proposed rewrite block

Each section has a fenced ```graphql block above the checklist
labelled `**Proposed rewrite** (edit if needed):`. Its contents are
the literal text that `apply` writes when `apply the rewrite above`
is checked. The analyzer pre-fills the block with `$.` fortifications
applied to every token the heuristic classified `keep-v0.3`; tokens
classified `embrace-v0.4` stay as-is.

To customize a rewrite, the developer edits the block. To revert any
specific fortification, they delete the `$.` prefix on that line. To
accept a stricter interpretation than the analyzer suggested, they
flip the checkbox (or edit the block to do nothing — same effect, but
the checkbox is clearer).

### Status field (added by apply)

After `connect-migrate apply` runs, it appends a `**Status:**` line to
each section:

- `applied` — source edited from the Proposed rewrite block.
- `unchanged` — left as-is.
- `error: <reason>` — apply failed for this section.

The file remains on disk as a durable audit record of what happened.

---

## Boundary conditions

These come up rarely but are worth knowing:

- **`legacy_object_to_lit_object`** — a cosmetic AST shape difference
  from the unification itself. Same evaluation semantics under both
  grammars. `analyze` does not emit these as sites; if you see one in
  a recommendations file from a prior tool version, check `leave the
  source unchanged` for that section.
- **`v04_only_accepts`** — the selection uses v0.4-only syntax (e.g.
  the `…` spread). The developer is already committed to v0.4 here; no
  migration is possible or needed. `analyze` does not emit these; if
  you encounter one in source while reviewing, leave it alone.
- **`v03_only_accepts`** — should never appear in v0.4 after the
  parser fix. If you see one, treat it as a bug in `connect-migrate`
  and escalate (file an issue against the connect-migrate repo).
- **Pre-existing syntax errors** — selections that don't parse under
  either grammar. `analyze` reports these separately at the top of
  the file under a "could not parse" heading. They're not migration
  targets — they were already broken — but they're worth surfacing so
  the developer can fix them.

## Tone

- Read the developer's code; don't speculate. Their REST API
  knowledge beats your priors.
- Lead with the source range and the proposed before/after. Don't
  bury the diff under prose.
- It is correct and often preferable to check `leave the source
  unchanged` on a section. That isn't a missed fix — it's a
  deliberate upgrade to the cleaner v0.4 reading.
- For genuinely ambiguous sites, ask. The developer pays one extra
  message and avoids a behavior regression.
- After `apply`, summarize: how many sites changed, how many were left
  alone, where the durable record lives. Don't claim success unless
  the post-apply analyze reports zero unintended divergence.

<!-- FOLLOW-UP: this file is duplicated at
     apollographql/router:apollo-federation/src/connectors/migration/agent_guide.md
     which is embedded into the binary via `--agent-guide`. Future work:
     decide between (a) CI-enforced hash match, (b) fetch this file at
     build time, or (c) drop the embed entirely and rely on the install
     having put SKILL.md on disk. -->
