# Security

This document explains where `connect-migrate`'s code comes from, what the
tool can and cannot do to your system, and how to verify all of it
yourself. The short version: the tool is a read-only analyzer compiled
from a pinned commit of a public Apollo repository, built by GitHub
Actions, and integrity-checked at install time — and every link in that
chain is auditable from this repository.

## Reporting a vulnerability

Report security issues privately through
[GitHub's security advisory system](https://github.com/apollographql/connect-migrate/security/advisories/new)
rather than opening a public issue. Please do not disclose a
vulnerability publicly until a fix is available.

---

## Trust model

Running `connect-migrate` as part of a migration asks you to trust three
distinct things. They are worth separating, because they carry very
different risk and each is anchored by something you can check:

| You trust… | …to do what | Anchored by |
|---|---|---|
| **The binary** | Read your schema files and emit a migration manifest | Pinned-source provenance + `SHA256SUMS` (below) |
| **The install script** | Fetch the right binary, verify it, drop it in user space | A short, HTTPS-only, no-`sudo` script you can read end-to-end |
| **The agent** | Apply edits to your schemas based on the manifest | **You / your AI assistant** — see below |

The key design point: **the binary never edits your files.** By design
there is no `apply` subcommand. `analyze` reads schemas and writes a
manifest; a human or an AI agent then reviews that manifest and makes the
edits, in your own editing session. So the actor with write access to
your source is never the downloaded binary — it is you, or an assistant
you are already supervising, working from a manifest you can read first.
That separation is the most important security property of the whole
flow, and it is structural, not a promise.

---

## What the tool does — and what it can't

`connect-migrate` exposes exactly two subcommands:

- **`analyze [PATH]…`** — walks the paths you give it, reads `.graphql`
  schema files, parses every `@connect(selection: …)` directive, and
  writes a migration **manifest** to stdout (or to a file you name with
  `-o`). It reads your schemas; it never modifies them. The only file it
  writes is the manifest you asked for.
- **`agent-guide`** — prints text embedded in the binary at compile time
  to stdout. No file access, no network.

What that means for its blast radius:

- **No writes to your schemas.** The migration edits are made later, by
  you or your agent, from the manifest — not by this binary.
- **Local files only.** The documented interface reads the paths you pass
  and writes only the manifest. It has no outbound-network, telemetry, or
  crash-reporting feature.
- **No elevated privileges.** It runs entirely as your own user; nothing
  in the tool or its installer requires `sudo`.

---

## Binary provenance: where the code comes from

The tool ships as a native binary because it embeds the **actual Apollo
Connectors parser** from the
[`apollographql/router`](https://github.com/apollographql/router)
repository — specifically the `apollo-federation` crate's
`connect-migrate` feature under `apollo-federation/src/connectors/migration/`.
This is deliberate: `analyze`'s entire value is that it dual-parses each
selection with the *exact same grammar the router uses at composition
time*. A shell-script or JavaScript reimplementation couldn't reproduce
that grammar faithfully, and a subtly-wrong copy would defeat the
behavior-preserving contract the migration depends on.

The trust chain from source to installed binary:

```
apollographql/router  (Rust source, pinned to a full 40-char commit SHA)
         │
         │  GitHub Actions: checkout @ pinned SHA → cargo build --release
         ▼
GitHub Releases  (connect-migrate-<platform>  +  SHA256SUMS)
         │
         │  install.sh: download binary, download SHA256SUMS,
         │              verify checksum, then install
         ▼
~/.local/bin/connect-migrate   (read-only analyzer; never edits your schemas)
```

### The source commit is pinned and immutable

Every tagged release pins an exact 40-character `RELEASE_ROUTER_REF` SHA
in [`.github/workflows/release.yml`](.github/workflows/release.yml) — a
full commit hash, never a branch or tag, so the release is built from one
specific, immutable revision of the router source. (The workflow comment
documents why a full SHA is required: `actions/checkout` treats a short
SHA as a branch pattern and silently fails to resolve it.) You can read
the workflow at any release tag to learn precisely which router commit
that binary was built from.

### The build runs in the open

The release workflow runs on GitHub's hosted runners (`macos-latest`,
`ubuntu-latest`, `windows-latest`) and every step is visible in the
workflow file: check out `apollographql/router` at the pinned SHA,
install the Rust toolchain via `dtolnay/rust-toolchain`, run
`cargo build --release --bin connect-migrate --features connect-migrate`,
strip the binary (on native targets), smoke-test it
(`connect-migrate --version` and `agent-guide`), and upload it as a
release artifact. The release job then computes `SHA256SUMS` over all the
collected binaries with `sha256sum`. There is no obfuscation step, no
post-compilation bundling, and no third-party code injected between the
Rust build and the published artifact.

### Integrity is checked at install time

Every release includes a `SHA256SUMS` file covering all platform
binaries. `install.sh` downloads it and verifies the binary against it
*before* moving anything into your install directory. One caveat worth
knowing: verification needs `sha256sum` (GNU coreutils) or `shasum`
(macOS) on `PATH`; if neither is present the script prints a warning and
continues rather than aborting — so in a stripped-down environment,
confirm one of those tools exists, or verify by hand:

```sh
# Download the matching SHA256SUMS for your release, alongside the binary:
sha256sum   --check SHA256SUMS    # Linux / GNU coreutils
shasum -a 256 --check SHA256SUMS  # macOS
```

---

## The install script

The recommended install is a piped script:

```sh
curl -fsSL https://raw.githubusercontent.com/apollographql/connect-migrate/main/install.sh | sh
```

Piping a remote script into a shell deserves scrutiny, so here is exactly
what [`install.sh`](install.sh) does and doesn't do:

| Property | Detail |
|---|---|
| **Transport** | Every fetch is HTTPS, to `api.github.com` and `github.com` (or `raw.githubusercontent.com` for the script itself) |
| **Integrity** | Downloads `SHA256SUMS` separately and verifies the binary before installing (needs `sha256sum`/`shasum`; warns and continues if neither exists) |
| **Privilege** | No `sudo`; installs to `$HOME/.local/bin` by default (override with `CONNECT_MIGRATE_INSTALL_DIR`) |
| **Temp files** | All downloads land in a `mktemp -d` directory, removed by an `EXIT` trap |
| **Token handling** | `GH_TOKEN`/`GITHUB_TOKEN` (or `gh auth token`) is sent only as an `Authorization` header to GitHub; never logged, never written to disk |
| **Side effects** | Downloads, verifies, and moves a single binary — no package manager, no shell-rc edits (it only *prints* a `PATH` hint if needed) |

If you would rather read before you run — always a reasonable choice with
a piped installer — download it first, inspect it, then execute:

```sh
curl -fsSL https://raw.githubusercontent.com/apollographql/connect-migrate/main/install.sh -o install.sh
less install.sh
sh install.sh
```

Two implementation details are worth calling out for the security-minded:

- **The auth token never reaches the file host.** While the repository is
  private, the script authenticates to the GitHub *API asset* endpoint,
  which responds with a pre-signed redirect to the file host. Because the
  redirect target is pre-signed, the `Authorization` header is not (and
  must not be) replayed to it — so your GitHub token is sent only to
  `api.github.com`, never to the storage backend. Once the repository is
  public, the script uses anonymous direct-download URLs and no token is
  involved at all.
- **No `sudo`, ever.** The script installs into your home directory and
  explicitly checks for write permission rather than escalating.

---

## Building from source

You never have to use a pre-built binary at all — you can compile your
own from the same source the releases are built from. The tool is just a
binary target of the upstream `apollo-federation` crate, behind the
`connect-migrate` cargo feature.

```sh
# 1. Clone the upstream router source.
git clone https://github.com/apollographql/router.git
cd router

# 2. (Optional but recommended) check out the exact commit a given
#    release was built from — its RELEASE_ROUTER_REF (see step 1 of
#    "Auditing a release" below for how to find it). Omit this to build
#    from the current router tip instead.
git checkout <RELEASE_ROUTER_REF>

# 3. Build the connect-migrate binary. router pins its own Rust
#    toolchain via rust-toolchain.toml, so rustup selects the right
#    compiler automatically — you don't choose one.
cd apollo-federation
cargo build --release --bin connect-migrate --features connect-migrate

# 4. The binary lands in the workspace target dir:
../target/release/connect-migrate --version
```

That `cargo build` line is exactly what the release workflow runs (it
adds `--target <triple>` for cross-platform output; drop it and you get a
native binary for your own machine). Two notes:

- **Version string.** The version is baked in at compile time from the
  `CONNECT_MIGRATE_VERSION` environment variable, defaulting to
  `0.0.0-dev`. To stamp a specific version, prefix the build:
  `CONNECT_MIGRATE_VERSION=0.0.8 cargo build --release …`.
- **Install it like any binary.** Copy the result onto your `PATH`, e.g.
  `cp ../target/release/connect-migrate ~/.local/bin/`. No installer and
  no `SHA256SUMS` step is involved when you build your own — you already
  know the provenance, because you compiled it.

A from-source build is the strongest provenance you can have: there is no
downloaded artifact to trust, only source you can read.

---

## Auditing a release

If you do use a published binary, you can independently confirm both
*what the code is* and *that the artifact you got matches what was
published*:

1. **Find the source commit.** Read `RELEASE_ROUTER_REF` from the
   workflow at the release tag:
   ```sh
   gh api "repos/apollographql/connect-migrate/contents/.github/workflows/release.yml?ref=<release-tag>" \
     --jq '.content' | base64 -d | grep RELEASE_ROUTER_REF
   ```
2. **Read the source.** Browse `apollographql/router` at that SHA and
   inspect `apollo-federation/src/connectors/migration/` — this is the
   complete logic behind `analyze`.
3. **Rebuild it.** Follow [Building from source](#building-from-source)
   with that SHA checked out. Note that Rust release binaries are **not**
   guaranteed to be bit-for-bit identical across machines without a
   dedicated reproducible-build setup, so a differing SHA256 from your
   local build does **not** by itself indicate tampering. The published
   `SHA256SUMS` is the integrity anchor for the *released* artifacts; the
   pinned source is the anchor for *what the tool does*. Use step 2 to
   audit behavior and `SHA256SUMS` to confirm you received the bytes that
   were published — and if you want to skip the download-trust question
   entirely, just run your own build from step 3.

---

## Code signing

The released binaries are **not** currently Apple-notarized or
Authenticode-signed. Installing via `install.sh` or `gh release download`
is unaffected (those paths don't set the macOS quarantine attribute). If
you instead download a macOS binary through a browser, Gatekeeper may
quarantine it; clear it with `xattr -d com.apple.quarantine <file>` after
you've verified its checksum, or use the script/`gh` install path.

---

## Supported platforms

| Platform | Release asset |
|---|---|
| macOS (Apple Silicon) | `connect-migrate-darwin-arm64` |
| macOS (Intel) | `connect-migrate-darwin-x64` |
| Linux x86-64 | `connect-migrate-linux-x64` |
| Linux ARM64 | `connect-migrate-linux-arm64` |
| Windows x86-64 | `connect-migrate-win32-x64.exe` |

`install.sh` covers macOS and Linux; Windows users download the `.exe`
from the [Releases page](https://github.com/apollographql/connect-migrate/releases)
or via `gh release download`.

---

## License

`connect-migrate` is licensed under the
[Elastic License 2.0](LICENSE), as is the upstream Rust source in
`apollographql/router`.
