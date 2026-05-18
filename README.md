# connect-migrate

CLI + agent skill for upgrading [Apollo Connectors](https://www.apollographql.com/docs/graphos/connectors) schemas across `connect/v0.X` spec versions.

The current focus is **v0.3 → v0.4** — the [SubSelection/LitObject grammar unification](https://github.com/apollographql/router/pull/9261) introduced in `connect/v0.4`. A small but important class of `@connect(selection: …)` expressions changes meaning between the two specs; `connect-migrate` finds those sites in your project, classifies them by intent, and applies the chosen transformations.

> **Status:** preview. v0.0.1 ships the agent guide and the binary skeleton; the `analyze`/`apply` subcommands land in subsequent releases.

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
connect-migrate --version       # connect-migrate 0.0.1
connect-migrate agent-guide     # prints the embedded migration guide
```

## How it works (today)

For now, `connect-migrate` exposes one subcommand:

- **`connect-migrate agent-guide`** — prints a migration guide for an agent (or a human) to follow when walking a project through `connect/v0.3` → `connect/v0.4`. The full text is embedded in the binary; no network access needed once installed.

The plan is for the binary to grow `analyze` (produces a `recommendations.md` summarizing every site that needs attention) and `apply` (executes the developer's chosen actions from that file) in subsequent releases.

## Layered design

Three layers, increasing in agent integration:

1. **Binary on `$PATH`** — universal; works for any agent that can shell out.
2. **`SKILL.md`** *(top of this repo)* — the per-site triage rules in plain markdown. Drop into Claude Code, Cursor, Cline, or any agent that consumes skill prose.
3. **Claude Code plugin** *(planned)* — `/plugin install apollographql/connect-migrate` registers the skill + the binary.

## Source of truth

The Rust crate is upstream in [`apollographql/router`](https://github.com/apollographql/router) at `apollo-federation/src/connectors/migration/`. This repo handles cross-platform release builds (`.github/workflows/release.yml`) pinning a known-good router commit.

See [router commit `47c83ecf0`](https://github.com/apollographql/router/tree/47c83ecf0/apollo-federation/src/connectors/migration) for the current skeleton.

## License

MIT — see [LICENSE](LICENSE).
