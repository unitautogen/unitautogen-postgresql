#!/usr/bin/env bash
# Install UnitAutogen for PostgreSQL on Linux (x86-64).
# Downloads the newest release (pre-releases included), verifies its SHA-256, and extracts it.
#
# Usage:
#   ./install.sh [install_dir]     (default: ~/.local/bin)
#   curl -fsSL https://raw.githubusercontent.com/unitautogen/unitautogen-postgresql/main/scripts/install.sh | bash
set -euo pipefail

REPO="unitautogen/unitautogen-postgresql"
INSTALL_DIR="${1:-$HOME/.local/bin}"

die() { echo "Error: $*" >&2; exit 1; }

case "$(uname -m)" in
    x86_64|amd64) : ;;
    *) die "UnitAutogen runs on x86-64 Linux only (this machine is $(uname -m))." ;;
esac
command -v curl >/dev/null 2>&1 || die "curl is required."

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "Fetching the newest release of $REPO ..."
# /releases lists every published release, newest first, pre-releases included.
# (/releases/latest skips pre-releases, so it is not used.)
api="$(curl -fsSL -H 'Accept: application/vnd.github+json' \
        "https://api.github.com/repos/$REPO/releases?per_page=20")" \
    || die "could not reach the GitHub API. Download the build by hand from https://github.com/$REPO/releases"

# The first dist-Linux asset in the list belongs to the newest release that has one.
url="$(printf '%s' "$api" | grep -oE 'https://[^"]*/releases/download/[^"]*/dist-Linux-[^"/]*\.(tar\.gz|zip)' | head -n1 || true)"
[ -n "$url" ] || die "no dist-Linux-<version> (.tar.gz or .zip) asset was found in any release."

file="$(basename "$url")"
base="${url%/*}"                                   # .../releases/download/<tag>
tag="${base##*/}"
echo "Release $tag: downloading $file ..."
curl -fsSL "$url" -o "$tmp/$file"

# Checksum file of the SAME release, if it has one.
if printf '%s' "$api" | grep -qF "\"$base/SHA256SUMS.txt\""; then
    curl -fsSL "$base/SHA256SUMS.txt" -o "$tmp/SHA256SUMS.txt"
    line="$(grep -E "[[:space:]]\*?$file\$" "$tmp/SHA256SUMS.txt" | head -n1 || true)"
    [ -n "$line" ] || die "SHA256SUMS.txt in release $tag has no line for $file."
    expected="$(printf '%s' "$line" | awk '{print tolower($1)}')"
    actual="$(sha256sum "$tmp/$file" | awk '{print $1}')"
    [ "$expected" = "$actual" ] || die "checksum mismatch for $file (expected $expected, got $actual)."
    echo "Checksum verified."
else
    echo "Note: release $tag has no SHA256SUMS.txt; the archive was not verified." >&2
fi

# The archive may hold the files at its root or inside a dist-Linux-<version> folder.
mkdir -p "$tmp/x"
case "$file" in
    *.zip) if command -v unzip >/dev/null 2>&1; then unzip -q "$tmp/$file" -d "$tmp/x"
           else python3 -m zipfile -e "$tmp/$file" "$tmp/x"; fi ;;
    *)     tar -xzf "$tmp/$file" -C "$tmp/x" ;;
esac
bin="$(find "$tmp/x" -type f -name unitautogen | head -n1)"
[ -n "$bin" ] || die "unitautogen not found in $file."
src="$(dirname "$bin")"

# The build folder carries its own SHA256SUMS for the binary; check it too.
if [ -f "$src/SHA256SUMS" ]; then
    ( cd "$src" && sha256sum --quiet -c SHA256SUMS ) || die "the binary does not match the SHA256SUMS inside $file."
    echo "Binary checksum verified."
fi

mkdir -p "$INSTALL_DIR"
cp -R "$src"/. "$INSTALL_DIR"/
chmod +x "$INSTALL_DIR/unitautogen"

if ! "$INSTALL_DIR/unitautogen" --version >/dev/null 2>&1; then
    echo "Warning: '$INSTALL_DIR/unitautogen --version' did not run. It needs x86-64 Linux with glibc 2.31 or newer." >&2
fi

echo ""
echo "Installed $("$INSTALL_DIR/unitautogen" --version 2>/dev/null || echo "$tag") to $INSTALL_DIR"
echo "Run it with:  $INSTALL_DIR/unitautogen --help"
case ":$PATH:" in
    *":$INSTALL_DIR:"*) : ;;
    *) echo "Tip: add $INSTALL_DIR to your PATH to call 'unitautogen' from anywhere." ;;
esac
