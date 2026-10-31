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
url="$(printf '%s' "$api"       | grep -o 'https://[^"]*/dist-Linux-[^"]*\.tar\.gz' | head -n1)"
sums_url="$(printf '%s' "$api"  | grep -o 'https://[^"]*SHA256SUMS\.txt'    | head -n1)"
[ -n "$url" ] || { echo "No dist-Linux-<version>.tar.gz asset was found in the latest release." >&2; exit 1; }

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

mkdir -p "$INSTALL_DIR"
tar -xzf "$tmp/$file" -C "$INSTALL_DIR"
chmod +x "$INSTALL_DIR/unitautogen" 2>/dev/null || true

echo ""
echo "Installed to $INSTALL_DIR"
echo "Run it with:  $INSTALL_DIR/unitautogen --help"
case ":$PATH:" in
    *":$INSTALL_DIR:"*) : ;;
    *) echo "Tip: add $INSTALL_DIR to your PATH to call 'unitautogen' from anywhere." ;;
esac
