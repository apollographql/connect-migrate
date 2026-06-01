#!/usr/bin/env bash
#
# make-workdir.sh — build an isolated work directory for one eval agent.
#
# The agent is given ONLY this directory. It is a fresh git repo whose single
# commit is the seed (pre-migration) fixtures: no migration history, no other
# branches, no remotes. This is the load-bearing integrity control — it means an
# agent cannot recover the expected answer via `git log --all`, `git show <ref>`,
# or by reading another run's branch. (See README.md → "Integrity invariants".)
#
# Usage: make-workdir.sh <dest-dir>
#
set -euo pipefail

eval_root="$(cd "$(dirname "$0")/.." && pwd)"
dest="${1:?usage: make-workdir.sh <dest-dir>}"

if [ -e "$dest" ]; then
  echo "make-workdir: refusing to overwrite existing path: $dest" >&2
  exit 1
fi

mkdir -p "$dest/schemas"
cp "$eval_root"/fixtures/*.graphql "$dest/schemas/"

git -C "$dest" init -q
git -C "$dest" add -A
git -C "$dest" \
  -c user.email=eval@connect-migrate.invalid \
  -c user.name="connect-migrate eval" \
  commit -q -m "seed: connector schemas to migrate"

# Integrity assertions: exactly one commit, no remotes, no extra refs.
commits="$(git -C "$dest" rev-list --all --count)"
remotes="$(git -C "$dest" remote)"
if [ "$commits" -ne 1 ] || [ -n "$remotes" ]; then
  echo "make-workdir: integrity check FAILED (commits=$commits remotes='$remotes')" >&2
  exit 1
fi

echo "work dir ready: $dest"
echo "  - single seed commit, no migration history, no remotes"
echo "  - hand this directory to the agent together with prompt.txt"
