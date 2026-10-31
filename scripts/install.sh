#!/usr/bin/env bash
# Install UnitAutogen for PostgreSQL on Linux (x86-64).
# Downloads the latest release, verifies its SHA-256, and extracts it.
#
# Usage:
#   ./install.sh [install_dir]     (default: ~/.local/bin)
set -euo pipefail

REPO="unitautogen/unitautogen-postgresql"
INSTALL_DIR="${1:-$HOME/.local/bin}"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "Fetching the latest release of $REPO ..."
api="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest")"
url="$(printf '%s' "$api"       | grep -oE 'https://[^"]*/dist-Linux-[^"]*\.(tar\.gz|zip)' | head -n1)"
sums_url="$(printf '%s' "$api"  | grep -o 'https://[^"]*SHA256SUMS\.txt'    | head -n1)"
[ -n "$url" ] || { echo "No dist-Linux-<version> (.tar.gz or .zip) asset was found in the latest release." >&2; exit 1; }

file="$(basename "$url")"
echo "Downloading $file ..."
curl -fsSL "$url" -o "$tmp/$file"

if [ -n "$sums_url" ]; then
    curl -fsSL "$sums_url" -o "$tmp/SHA256SUMS.txt"
    ( cd "$tmp" && grep " $file\$" SHA256SUMS.txt | sha256sum -c - )
    echo "Checksum verified."
else
    echo "SHA256SUMS.txt not found in the release; skipping checksum verification." >&2
fi

# The archive may hold the files at its root or inside a dist-Linux-<version> folder.
mkdir -p "$tmp/x" "$INSTALL_DIR"
case "$file" in
    *.zip) if command -v unzip >/dev/null 2>&1; then unzip -q "$tmp/$file" -d "$tmp/x"; else python3 -m zipfile -e "$tmp/$file" "$tmp/x"; fi ;;
    *)     tar -xzf "$tmp/$file" -C "$tmp/x" ;;
esac
bin="$(find "$tmp/x" -type f -name unitautogen | head -n1)"
[ -n "$bin" ] || { echo "unitautogen not found in $file" >&2; exit 1; }
cp -R "$(dirname "$bin")"/. "$INSTALL_DIR"/
chmod +x "$INSTALL_DIR/unitautogen"

echo ""
echo "Installed to $INSTALL_DIR"
echo "Run it with:  $INSTALL_DIR/unitautogen --help"
case ":$PATH:" in
    *":$INSTALL_DIR:"*) : ;;
    *) echo "Tip: add $INSTALL_DIR to your PATH to call 'unitautogen' from anywhere." ;;
esac
