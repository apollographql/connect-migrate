# connect-migrate

CLI + agent skill for upgrading [Apollo Connectors](https://www.apollographql.com/docs/graphos/connectors) schemas across `connect/v0.X` spec versions.

The current target is **`connect/v0.4`** — the [SubSelection/LitObject grammar unification](https://github.com/apollographql/router/pull/9261) introduced there changes how a small but important class of `@connect(selection: …)` expressions parses. `connect-migrate analyze` reads each schema's linked `connect/v0.n` version, finds the selections that change meaning relative to v0.4, and emits a **manifest** that an agent applies and (where genuinely ambiguous) interviews the developer about.

> **Status:** preview / experimental — no stability guarantees. `analyze` and `agent-guide` ship today; the migration is driven by an agent following [`SKILL.md`](SKILL.md) — there is no `apply` subcommand by design (see below). Latest release: see the [Releases page](https://github.com/apollographql/connect-migrate/releases).

## Why `connect/v0.4` (and why migrate at all)

`connect/v0.4` unifies what were two parallel constructs in the v0.3 mapping language — `SubSelection` field blocks (`{ … }`) and object literals — into a single grammar (`LitExpr`). That unification is worth a migration:

- **JSON now pastes directly as JSONSelection.** Because object literals are first-class in v0.4, a plain JSON object *is* valid `@connect(selection:)` code — you can paste a sample API response straight in and shape it from there, instead of hand-translating JSON into the old mapping dialect. This is the single most useful day-to-day win, for humans and agents alike.
- **One composable grammar instead of two.** Literals, objects, and field selections now nest and compose uniformly, with far fewer special-case parsing rules and surprises.
- **Intent becomes explicit.** In v0.3 a bare `null`/`true` or a quoted `"USD"` parsed as a *field reference*; when that field didn't exist the result normalized to `null`, so a literal-looking value only "worked" by accident. v0.4 reads them as real literals — what most authors meant — and lets you write a deliberate field reference with `$.` when you actually want one.
- **Room to grow.** The unified grammar is what makes newer expression features (object literals, nullish/none-coalescing `??` / `?!`, nested literal expressions) possible at all.

**The migration risk is real but narrow and mechanical.** The only breaking change is that tokens which *were* field references in v0.3 (quoted keys, bare keywords) now read as literals. The behavior-preserving fix is a deterministic `$.` fortification — and finding and applying exactly those is what `connect-migrate` is for. A bounded, tool-assisted, behavior-preserving edit in exchange for a coherent, expressive mapping language is a good trade.

## Install

> **Before anything below works:** this repo is **private**, so you need **read access** to it (as a collaborator or via an Apollo team) and the [GitHub CLI](https://cli.github.com/) **authenticated** (`gh auth login`). Without both, every download — including `gh release download` — returns a `404`. Once the repo is public, the plain `curl …/install.sh | sh` one-liner works with no auth.

### Unix (macOS, Linux)

Install with the one-line script:

```sh
curl -fsSL https://raw.githubusercontent.com/apollographql/connect-migrate/main/install.sh | sh
```

`install.sh` drops the binary in `~/.local/bin` by default (override with `CONNECT_MIGRATE_INSTALL_DIR=…`; pick a version with `CONNECT_MIGRATE_VERSION=v0.0.N`). Ensure `~/.local/bin` is on your `PATH`.

Or download a release asset directly with the [GitHub CLI](https://cli.github.com/):

```sh
gh release download -R apollographql/connect-migrate \
  -p "*$(uname -s | tr 'A-Z' 'a-z')-$(uname -m | sed 's/x86_64/x64/;s/aarch64/arm64/')*" \
  --dir /tmp/cm && mkdir -p ~/.local/bin && chmod +x /tmp/cm/connect-migrate-* \
  && mv /tmp/cm/connect-migrate-* ~/.local/bin/connect-migrate
```

### Windows

Windows binaries ship as Release assets but the install script is Unix-only. Grab `connect-migrate-win32-x64.exe` from the [Releases page](https://github.com/apollographql/connect-migrate/releases) directly, or via the GitHub CLI:

```pwsh
gh release download -R apollographql/connect-migrate --pattern 'connect-migrate-win32-x64.exe'
```

### Verify

```sh
connect-migrate --version       # e.g. connect-migrate 0.0.4
connect-migrate agent-guide     # prints the embedded migration guide
```

## How it works

The migration is driven by an agent following [`SKILL.md`](SKILL.md). The binary does the analysis; the agent does the editing and the conversation. There is **no `apply` subcommand** — the manifest *is* the interface, and the agent applies edits in-session so the developer's flow is never broken.

`connect-migrate` exposes two subcommands:

- **`connect-migrate analyze [PATH]...`** — walks the given paths (default `.`), finds every `@connect(selection: …)` directive, and for each schema dual-parses every selection at *its own* linked `connect/v0.n` against the `connect/v0.4` target. Writes a **manifest** to stdout (pipe to a file, or pass `-o`/`--output`; `--format json` emits one JSONL record per site). The manifest sorts each divergent site into three buckets:
  - **Rewrites to apply** — deterministic `$.` fortifications that preserve a v0.3-era field access v0.4 would otherwise read as a literal. Each carries a machine block with an exact locator and replacement.
  - **No action needed** — bare `null`/`true`/`false` whose v0.4 reading is output-identical.
  - **Questions for the developer** — only the genuinely ambiguous, structural divergences.
  It also reports an `Upgrade` line (source versions → v0.4), the schemas in scope, a non-fatal "Heads up" section for selections that fail to parse, and the ready-to-paste `connect/v0.4` `@link`.
- **`connect-migrate agent-guide`** — prints the migration skill prose embedded in the binary (the body of [`SKILL.md`](SKILL.md), minus its skill-registry frontmatter). Pipe into your agent of choice, or read it manually.

## Agent skill

[`SKILL.md`](SKILL.md) is the canonical text an agent (Claude Code, Cursor, Cline, or any other) follows. The flow:

1. **Analyze** — run `connect-migrate analyze` to produce the manifest.
2. **Apply rewrites** — apply the deterministic fortifications from the manifest's machine blocks (curate the list first if needed: delete a block to skip it, edit `rewrite_to` to change it).
3. **Interview** — put only the genuine questions to the developer, distilled (one question per distinct decision, not per site), and apply their answers.
4. **Verify, then bump** — re-run `analyze` **while still on the old `connect/v0.n`** to confirm zero divergent sites (that's the check that proves the fortifications took), and *only then* bump each schema's `@link` to `connect/v0.4` as the last step. A post-bump re-analyze is hollow — once a schema is on v0.4 the tool has nothing left to diff and reports clean regardless.

You can also **resume from an existing (possibly curated) manifest** — hand it back and the agent applies what it lists, without re-analyzing. The same prose is embedded in the binary as `connect-migrate agent-guide` for offline use.

## Layered design

Three layers, increasing in agent integration:

1. **Binary on `$PATH`** — universal; works for any agent that can shell out.
2. **`SKILL.md`** *(top of this repo)* — the manifest format + migration flow in plain markdown. Drop into Claude Code, Cursor, Cline, or any agent that consumes skill prose.
3. **Claude Code plugin** *(planned)* — `/plugin install apollographql/connect-migrate` registers the skill + the binary.

## Why a native binary (not a script)

`connect-migrate` doesn't *approximate* the migration — it runs the **actual Apollo Connectors parser**, compiled in. `analyze` dual-parses every `@connect(selection: …)` with the genuine `JSONSelection` grammar at both the schema's linked version and `connect/v0.4`, then diffs the two ASTs. A hand-rolled regex or JS reimplementation couldn't reproduce that grammar faithfully, and a subtly-wrong copy would defeat the whole point: the no-surprises, behavior-preserving contract depends on the analysis being *exactly* what the router does at composition time.

That parser is Rust (the `apollo-federation` crate), so the tool ships as a small, self-contained native binary per platform — no Node or Python runtime to install, fast, and bit-for-bit the same code path the router uses. Hence the five-platform release matrix (`darwin-arm64/x64`, `linux-arm64/x64`, `win32-x64`) with `SHA256SUMS`, rather than `npm install` or a shell script.

## Source of truth

The Rust crate is upstream in [`apollographql/router`](https://github.com/apollographql/router) at `apollo-federation/src/connectors/migration/`, behind the `connect-migrate` cargo feature. This repo handles cross-platform release builds (`.github/workflows/release.yml`), which check out a pinned router commit via `RELEASE_ROUTER_REF` — so a release ships from a specific router commit without that commit needing to be merged into router first.

## License

Elastic License 2.0 — see [LICENSE](LICENSE).
