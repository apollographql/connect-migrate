# Contributing to connect-migrate

Thanks for your interest in improving `connect-migrate`. Before you start,
the most important thing to know is **where the code you want to change
actually lives** — this repository is a packaging, distribution, and
documentation layer around a tool whose core is maintained elsewhere.

## Where to contribute what

The `connect-migrate` analyzer itself — the Rust that parses
`@connect(selection: …)` directives and produces the migration manifest —
is **not** in this repository. It is upstream in
[`apollographql/router`](https://github.com/apollographql/router) under
`apollo-federation/src/connectors/migration/`, behind the
`connect-migrate` cargo feature. This repo builds release binaries from a
pinned router commit (see [`SECURITY.md`](SECURITY.md) for the full
provenance chain).

So route your change to the right place:

| If you want to change… | Contribute to… |
|---|---|
| The analyzer's parsing, diffing, manifest output, or `analyze`/`agent-guide` behavior | [`apollographql/router`](https://github.com/apollographql/router) (`apollo-federation/src/connectors/migration/`) |
| The install script, release workflow, or platform matrix | **This repo** (`install.sh`, `.github/workflows/release.yml`) |
| The migration guide an agent follows | **This repo** ([`SKILL.md`](SKILL.md)) — note it is mirrored into the binary as `agent-guide`; see the follow-up comment at the bottom of `SKILL.md` |
| README, security docs, or this guide | **This repo** |
| The evaluation harness | **This repo** ([`eval/`](eval/)) |

If you're unsure which side a change belongs on, open an issue here first
and we'll point you the right way.

## Building and testing locally

To build the binary from source (the same build the release workflow
runs), follow the [Building from source](SECURITY.md#building-from-source)
steps in `SECURITY.md`.

The analyzer has golden/snapshot tests driven from this repo's eval
harness. With `connect-migrate` on your `PATH`:

```sh
cd eval
make test          # run analyzer golden/snapshot tests
make test UPDATE=1 # refresh snapshots after an intentional output change
```

See [`eval/README.md`](eval/README.md) for the full harness — including
how to run a cold agent evaluation against the migration skill.

## Opening a pull request

- **Keep PRs focused.** One logical change per PR; avoid unrelated
  formatting churn.
- **Update the docs alongside the code.** If you change install behavior,
  the release matrix, or the manifest format, update the relevant
  `README.md` / `SECURITY.md` / `SKILL.md` in the same PR.
- **CI must pass.** The eval golden tests run on changes under `eval/`;
  make sure they're green (or run `make test UPDATE=1` and commit the
  snapshot update if the change to output is intentional).
- **Explain the "why."** A short rationale in the PR description helps
  reviewers far more than a restatement of the diff.

## Code of Conduct

This project follows the Apollo
[Code of Conduct](https://github.com/apollographql/.github/blob/main/CODE_OF_CONDUCT.md),
which _all_ contributors are expected to follow. It describes the minimum
behavior expected of everyone participating in the project. Open,
diverse, and inclusive communities live and die on the basis of trust;
please help keep this one a place where anyone who wants to contribute
feels safe doing so.

## Security

Please do **not** report security vulnerabilities through public issues
or pull requests. See [`SECURITY.md`](SECURITY.md) for how to report them
privately.

## License

`connect-migrate` is licensed under the
[Elastic License 2.0](LICENSE). By contributing, you agree that your
contributions will be licensed under the same terms.
