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

### Step A2: triage each site (you are the analyzer here)

For each site `analyze` writes into `recommendations.md`, your job is
to choose a **recommended decision** based on what the source looks
like. The recommendation is your best guess; the developer can
override it before `apply` runs.

There are three buckets. Most sites belong cleanly to one of them.

#### Bucket 1 — Almost certainly a field reference (`keep-v0.3`)

The v0.3 reading was intentional and the v0.4 literal reading is wrong.
Heuristics for this bucket:

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

**Recommended:** `keep-v0.3`. Apply will rewrite `"@odata.nextLink"` to
`$."@odata.nextLink"` (or the corresponding `$.null` / `$.true` /
`$.false` form for bare-token field references).

#### Bucket 2 — Almost certainly a literal (`embrace-v0.4`)

The v0.4 reading is what the developer wanted all along; the v0.3
behavior was silently broken. Heuristics:

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

**Recommended:** `embrace-v0.4`. Apply makes no source change for these;
the v0.4 upgrade is itself the fix.

#### Bucket 3 — Ambiguous (no default recommendation)

Sites that don't fit either bucket cleanly. Examples: medium-length
strings that could plausibly be either a REST field name or an
intended literal; tokens used only on one branch of a `->match(…)`.

**Recommended:** leave the `Decision:` line empty (or write `???`),
and add a short note describing what's ambiguous. The developer must
fill it in.

### Step A3: write `recommendations.md`

`connect-migrate analyze` produces the file. You don't author it by
hand — but you do need to know the format, because Mode B reads it
back, and because the developer may ask why a particular field is
shaped the way it is.

See the [Recommendations format](#recommendations-format) section
below for the spec and a worked example.

### Step A4: hand off

Tell the developer the file is ready and what they should look for:

> I've written `recommendations.md` with N sites that need a decision.
> Most have a recommended choice (`keep-v0.3` or `embrace-v0.4`) you
> can leave as-is. The K ambiguous sites need your input — search the
> file for `Decision: ???`. When you're satisfied, run
> `connect-migrate apply recommendations.md` (or ask me to run it).

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

- **Unrecognized decision** — a `Decision:` field with a value other
  than `keep-v0.3` / `embrace-v0.4` / `skip` / `custom: …`.
- **Stale site identifier** — the source file the recommendation
  refers to has been edited and the site's content hash no longer
  matches. Re-run `connect-migrate analyze` to regenerate the file,
  then re-apply the developer's prior decisions.
  <!-- FOLLOW-UP: future versions may auto-refresh by re-running
       analyze under the hood and three-way-merging the developer's
       Decision fields onto the fresh sites. For now, prompt the
       developer to re-run analyze themselves. -->
- **Missing decision** — a `Decision: ???` (or empty) was left in the
  file.

### Step B2: apply for real

Once the dry-run looks right:

```sh
connect-migrate apply recommendations.md
```

This writes the source edits. `recommendations.md` is updated in place
with a `Status:` field on each site (`applied` / `skipped` /
`unchanged`) so it remains a durable record of what happened.

### Step B3: verify

`apply` automatically re-runs `analyze` after writing edits and
reports the result. If any site marked `keep-v0.3` still shows up as
divergent, that's a bug — surface it to the developer and don't claim
success.

Manual final sanity checks worth doing:

- Run `cargo check` (or `npm run check`, or the project's
  equivalent) — the source edits are syntactic only; they shouldn't
  affect typechecking, but a green build is reassurance.
- Spot-check 1–2 representative selections against real backend
  responses if a sandbox is available.

---

## Recommendations format

`connect-migrate analyze` writes a single markdown file with structured
identity comments and human-readable decisions. The format is
versioned via the leading `<!-- connect-migrate recommendations v1 -->`
comment; `apply` refuses to run against a file whose version it
doesn't recognize.

### Document structure

```markdown
<!-- connect-migrate recommendations v1 -->
<!-- generator: connect-migrate 0.X.Y -->
<!-- generated-at: 2026-05-18T18:34:00Z -->
<!-- project-root: . -->

# `connect/v0.3` → `connect/v0.4` migration recommendations

Generated by `connect-migrate analyze` on 2026-05-18.

Edit the `Decision:` line on each site below, then run:

    connect-migrate apply recommendations.md

**Decision values:**

- `keep-v0.3` — preserve the v0.3 field-reference reading by
  prepending `$.` to the token.
- `embrace-v0.4` — accept the new v0.4 literal reading; no source
  change.
- `skip` — make no change; do not raise this site again on future
  `analyze` runs.
  <!-- FOLLOW-UP: where the persistence marker lives in source is a
       Phase-4 implementation decision (in-line `# connect-migrate:
       ignore` GraphQL comment? sidecar `.connect-migrate-ignore`
       file?). Pin in Phase 4. -->

- `custom: <text>` — replace the token with the given text exactly.
  Use this only when you know what you're doing. Example: to keep
  the v0.3 field-reference reading *and* chain a subselection,
  override `keep-v0.3` (which only prepends `$.`) with
  `custom: $."foo-bar".baz`. The trailing characters after
  the `custom:` keyword become the literal replacement.

---

## site 1 of N — `subgraphs/billing/connector.graphql`

<!-- connect-migrate site v1
  id: fa3c7e92
  file: subgraphs/billing/connector.graphql
  line: 42
  col: 17
  coordinate: Invoice.partner
  kind: key_quoted_flipped_to_literal_string
  text: "sold-to"
  followed_by: nothing
-->

In `Invoice.partner`, the token `"sold-to"` will reparse as a JSON
string literal under `connect/v0.4`. Under `connect/v0.3` it was a
field reference to a backend field named `sold-to`.

```graphql
soldTo: "sold-to"
billTo: "bill-to"
```

The quoted text contains `-`, which is not valid in a GraphQL bare
identifier, so `"sold-to"` is almost certainly a REST field name.

**Decision:** `keep-v0.3`

---

## site 2 of N — `subgraphs/billing/connector.graphql`

<!-- connect-migrate site v1
  id: 7b22a014
  file: subgraphs/billing/connector.graphql
  line: 91
  col: 11
  coordinate: Invoice.status
  kind: key_flipped_to_literal_null
  text: null
  followed_by: nothing
-->

In `Invoice.status`, `status: null` will reparse as a literal `null`
value under `connect/v0.4`. Under `connect/v0.3` the parser tried to
look up a field named `null`, didn't find it, and returned undefined
(which GraphQL usually surfaced as `null` anyway).

```graphql
status: null
```

The v0.4 reading is almost certainly what was intended.

**Decision:** `embrace-v0.4`
```

### Per-site fields

The HTML comment block at the top of each site is the machine-readable
identity. `apply` parses it; everything else is free-form markdown.

| Field         | Required | Notes |
|---------------|----------|-------|
| `id`          | yes      | Stable content-hash of the site (8 hex chars). Survives line shifts in the source file. |
| `file`        | yes      | Path relative to `project-root`. |
| `line`, `col` | yes      | Position at analyze time. Updated automatically on apply if shifted. |
| `coordinate`  | yes      | GraphQL schema coordinate (`Type.field`). |
| `kind`        | yes      | One of: `key_quoted_flipped_to_literal_string`, `key_flipped_to_literal_null`, `key_flipped_to_literal_bool`, `key_field_flipped_to_literal_string`. |
| `text`        | yes      | The literal source text of the token (quoted strings include their quotes). |
| `followed_by` | yes      | One of: `nothing`, `sub_selection`, `key_access`, `method`, `question`. |

### Decision field

A site's `**Decision:**` line is the editable part. Whitespace is
forgiving; case is not. Recognized values:

- `keep-v0.3`
- `embrace-v0.4`
- `skip`
- `custom: <text>` — `<text>` is the literal replacement.
- empty or `???` — no decision yet; `apply` will refuse to touch this
  site and report it.

Add any explanatory prose around the decision freely — `apply` only
parses the line beginning with `**Decision:**` (or `Decision:` with
optional bold).

### Status field (added by apply)

After `connect-migrate apply` runs, it appends a `**Status:**` line to
each site:

- `applied: keep-v0.3` — source edited.
- `applied: custom` — source edited with custom replacement.
- `unchanged: embrace-v0.4` — left as-is.
- `unchanged: skip` — left as-is; recorded for future analyze runs.
- `error: <reason>` — apply failed for this site.

The file remains on disk as a durable record. Subsequent `analyze`
runs read prior `skip` decisions and respect them by default.

---

## Boundary conditions

These come up rarely but are worth knowing:

- **`legacy_object_to_lit_object`** — a cosmetic AST shape difference
  from the unification itself. Same evaluation semantics under both
  grammars. `analyze` does not emit these as sites; if you see one in
  a recommendations file from a prior tool version, mark it `skip`.
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
- It is correct and often preferable to leave a site as `embrace-v0.4`.
  That isn't a missed fix — it's a deliberate upgrade.
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
