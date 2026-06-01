# connect-migrate

CLI + agent skill for upgrading [Apollo Connectors](https://www.apollographql.com/docs/graphos/connectors) schemas across `connect/v0.X` spec versions.

The current target is **`connect/v0.4`** — the [SubSelection/LitObject grammar unification](https://github.com/apollographql/router/pull/9261) introduced there changes how a small but important class of `@connect(selection: …)` expressions parses. `connect-migrate analyze` reads each schema's linked `connect/v0.n` version, finds the selections that change meaning relative to v0.4, and emits a **manifest** that an agent applies and (where genuinely ambiguous) interviews the developer about.

> **Status:** preview, Apollo-internal. `analyze` and `agent-guide` ship today; the migration is driven by an agent following [`SKILL.md`](SKILL.md) — there is no `apply` subcommand by design (see below). Latest release: see the [Releases page](https://github.com/apollographql/connect-migrate/releases).

## Install

### Unix (macOS, Linux)

```sh
curl -fsSL https://raw.githubusercontent.com/apollographql/connect-migrate/main/install.sh | sh
```

By default this drops `connect-migrate` in `~/.local/bin`. Override with `CONNECT_MIGRATE_INSTALL_DIR=…`. Override the version with `CONNECT_MIGRATE_VERSION=v0.0.N`.

While this repo is private, the script needs a GitHub token — it picks up `GH_TOKEN`/`GITHUB_TOKEN`, or falls back to `gh auth token` if the [GitHub CLI](https://cli.github.com/) is installed and logged in.

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
- **`connect-migrate agent-guide`** — prints the migration skill prose embedded in the binary (byte-identical to [`SKILL.md`](SKILL.md)). Pipe into your agent of choice, or read it manually.

## Agent skill

[`SKILL.md`](SKILL.md) is the canonical text an agent (Claude Code, Cursor, Cline, or any other) follows. The flow:

1. **Analyze** — run `connect-migrate analyze` to produce the manifest.
2. **Apply rewrites** — apply the deterministic fortifications from the manifest's machine blocks (curate the list first if needed: delete a block to skip it, edit `rewrite_to` to change it).
3. **Interview** — put only the genuine questions to the developer, distilled (one question per distinct decision, not per site), and apply their answers.
4. **Verify** — re-run `analyze` and confirm a clean verdict, then bump each schema's `@link` to `connect/v0.4`.

You can also **resume from an existing (possibly curated) manifest** — hand it back and the agent applies what it lists, without re-analyzing. The same prose is embedded in the binary as `connect-migrate agent-guide` for offline use.

## Layered design

Three layers, increasing in agent integration:

1. **Binary on `$PATH`** — universal; works for any agent that can shell out.
2. **`SKILL.md`** *(top of this repo)* — the manifest format + migration flow in plain markdown. Drop into Claude Code, Cursor, Cline, or any agent that consumes skill prose.
3. **Claude Code plugin** *(planned)* — `/plugin install apollographql/connect-migrate` registers the skill + the binary.

## Source of truth

The Rust crate is upstream in [`apollographql/router`](https://github.com/apollographql/router) at `apollo-federation/src/connectors/migration/`, behind the `connect-migrate` cargo feature. This repo handles cross-platform release builds (`.github/workflows/release.yml`), which check out a pinned router commit via `RELEASE_ROUTER_REF` — so a release ships from a specific router commit without that commit needing to be merged into router first.

## License

MIT — see [LICENSE](LICENSE).
