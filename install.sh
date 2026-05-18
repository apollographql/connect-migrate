#!/usr/bin/env bash
#
# Install connect-migrate from GitHub Releases.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/apollographql/connect-migrate/main/install.sh | sh
#
# Environment variables (all optional):
#   CONNECT_MIGRATE_VERSION       Version to install, e.g. "v0.0.1". Default: "latest".
#   CONNECT_MIGRATE_INSTALL_DIR   Where to drop the binary. Default: "$HOME/.local/bin".
#   GH_TOKEN / GITHUB_TOKEN       GitHub auth token; used when present. Required only
#                                 while the connect-migrate repo is private; once it's
#                                 public, anonymous downloads work without a token.
#                                 If unset and `gh` is on PATH, `gh auth token` is
#                                 consulted as a fallback.
#
# Windows is not supported by this script. Windows users can download
# the win32-x64 .exe directly from the Releases page or via
# `gh release download` — see the README.

set -euo pipefail

REPO="apollographql/connect-migrate"
INSTALL_DIR="${CONNECT_MIGRATE_INSTALL_DIR:-$HOME/.local/bin}"
VERSION="${CONNECT_MIGRATE_VERSION:-latest}"

# --- output helpers ------------------------------------------------

if [ -t 2 ]; then
    bold=$(printf '\033[1m')
    red=$(printf '\033[31m')
    green=$(printf '\033[32m')
    yellow=$(printf '\033[33m')
    reset=$(printf '\033[0m')
else
    bold='' red='' green='' yellow='' reset=''
fi

info() { printf '%s%s%s\n' "$bold" "$1" "$reset" >&2; }
warn() { printf '%swarning:%s %s\n' "$yellow" "$reset" "$1" >&2; }
err()  { printf '%serror:%s %s\n'   "$red"    "$reset" "$1" >&2; exit 1; }

# --- platform detection --------------------------------------------

case "$(uname -s)" in
    Darwin) OS=darwin ;;
    Linux)  OS=linux ;;
    MINGW*|MSYS*|CYGWIN*) err "Windows is not supported by install.sh; download connect-migrate-win32-x64.exe from the Releases page directly." ;;
    *) err "unsupported OS: $(uname -s)" ;;
esac

case "$(uname -m)" in
    x86_64|amd64)  ARCH=x64 ;;
    arm64|aarch64) ARCH=arm64 ;;
    *) err "unsupported architecture: $(uname -m)" ;;
esac

PLATFORM="${OS}-${ARCH}"
BIN_NAME="connect-migrate-${PLATFORM}"

# --- GitHub auth token (private-repo workaround) -------------------

# Use explicit env, falling back to `gh auth token` if present. Anything
# we find here gets attached as `Authorization: token …` on requests to
# api.github.com and github.com release-download URLs. Once the repo is
# public, this becomes optional.
TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
if [ -z "$TOKEN" ] && command -v gh >/dev/null 2>&1; then
    TOKEN=$(gh auth token 2>/dev/null || true)
fi

# --- downloader detection ------------------------------------------

if command -v curl >/dev/null 2>&1; then
    if [ -n "$TOKEN" ]; then
        download() { curl -fsSL -H "Authorization: token $TOKEN" "$1" -o "$2"; }
    else
        download() { curl -fsSL "$1" -o "$2"; }
    fi
elif command -v wget >/dev/null 2>&1; then
    if [ -n "$TOKEN" ]; then
        download() { wget -q --header="Authorization: token $TOKEN" -O "$2" "$1"; }
    else
        download() { wget -qO "$2" "$1"; }
    fi
else
    err "neither curl nor wget is installed"
fi

# --- shasum detection ----------------------------------------------

if command -v sha256sum >/dev/null 2>&1; then
    sha256_check() { sha256sum --ignore-missing --check "$1"; }
elif command -v shasum >/dev/null 2>&1; then
    sha256_check() { shasum -a 256 --ignore-missing --check "$1"; }
else
    sha256_check() {
        warn "no sha256sum or shasum found; skipping checksum verification"
        return 0
    }
fi

# --- JSON parser detection -----------------------------------------

# Used only when downloading via the API asset endpoint (needs to map
# asset name → asset ID). When pulling directly from a public repo's
# /releases/download/ URLs (no auth), we never call this.
if command -v jq >/dev/null 2>&1; then
    asset_id_for_name() {
        jq -r ".assets[] | select(.name == \"$1\") | .id" < "$2"
    }
elif command -v python3 >/dev/null 2>&1; then
    asset_id_for_name() {
        python3 - "$1" "$2" <<'PY'
import json, sys
name, path = sys.argv[1], sys.argv[2]
with open(path) as f:
    release = json.load(f)
for asset in release.get("assets", []):
    if asset.get("name") == name:
        print(asset.get("id", ""))
        break
PY
    }
else
    asset_id_for_name() {
        err "no jq or python3 available to parse the GitHub release JSON; install one and retry"
    }
fi

# --- resolve version + fetch release metadata ----------------------

info "Installing connect-migrate for ${PLATFORM}..."

TMP=$(mktemp -d -t connect-migrate.XXXXXX)
# Best-effort cleanup; rely on the OS tmp reaper as a fallback.
trap 'rm -rf "$TMP" 2>/dev/null || true' EXIT

cd "$TMP"

if [ "$VERSION" = "latest" ]; then
    info "Resolving latest release..."
    download "https://api.github.com/repos/${REPO}/releases/latest" release.json
else
    info "Fetching release metadata for ${VERSION}..."
    download "https://api.github.com/repos/${REPO}/releases/tags/${VERSION}" release.json
fi

VERSION=$(sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' release.json | head -n 1)
[ -n "$VERSION" ] || err "could not determine version from release metadata"
info "Version: ${VERSION}"

# --- choose download mechanism -------------------------------------

# Direct /releases/download/ URLs require no auth for public repos
# but, on private repos, `curl -L` strips Authorization on the
# cross-host redirect to S3 and fails. The /releases/assets/{id}
# API endpoint returns a pre-signed S3 redirect that doesn't need
# auth on the redirect target — works for both.
#
# Pick the simpler direct path when we have no token (and trust the
# repo is public); otherwise go through the API endpoint.

download_release_file() {
    local name="$1" dest="$2"
    if [ -z "$TOKEN" ]; then
        download "https://github.com/${REPO}/releases/download/${VERSION}/${name}" "$dest"
        return
    fi
    local id
    id=$(asset_id_for_name "$name" release.json)
    [ -n "$id" ] || err "asset $name not found in release ${VERSION}"
    # The API asset endpoint serves the file directly with the right Accept header.
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL \
            -H "Authorization: token $TOKEN" \
            -H "Accept: application/octet-stream" \
            "https://api.github.com/repos/${REPO}/releases/assets/${id}" \
            -o "$dest"
    else
        wget -q \
            --header="Authorization: token $TOKEN" \
            --header="Accept: application/octet-stream" \
            -O "$dest" \
            "https://api.github.com/repos/${REPO}/releases/assets/${id}"
    fi
}

info "Downloading ${BIN_NAME}..."
download_release_file "$BIN_NAME" "$BIN_NAME"

info "Verifying SHA256..."
download_release_file SHA256SUMS SHA256SUMS
sha256_check SHA256SUMS

# --- install -------------------------------------------------------

mkdir -p "$INSTALL_DIR"
[ -w "$INSTALL_DIR" ] || err "no write permission for $INSTALL_DIR"

chmod +x "$BIN_NAME"
mv -f "$BIN_NAME" "${INSTALL_DIR}/connect-migrate"

VERSION_OUT=$("${INSTALL_DIR}/connect-migrate" --version)
info "Installed: ${INSTALL_DIR}/connect-migrate (${VERSION_OUT})"

# --- $PATH sanity --------------------------------------------------

case ":$PATH:" in
    *":${INSTALL_DIR}:"*) ;;
    *)
        warn "${INSTALL_DIR} is not in your \$PATH"
        warn "Add it to your shell rc:"
        warn "    export PATH=\"${INSTALL_DIR}:\$PATH\""
        ;;
esac

printf '\n%s%sNext:%s run %sconnect-migrate agent-guide%s to see the migration skill prose.\n' \
    "$bold" "$green" "$reset" "$bold" "$reset"
