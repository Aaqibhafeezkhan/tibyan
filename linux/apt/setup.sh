#!/bin/sh
# Adds the Tibyan APT repository to Debian / Ubuntu (amd64), then:
#   sudo apt install tibyan
# Usage: curl -fsSL https://apt.altibyan.app/setup.sh | sudo sh
set -eu
REPO=https://apt.altibyan.app
KEYRING=/usr/share/keyrings/tibyan.gpg
LIST=/etc/apt/sources.list.d/tibyan.list

[ "$(id -u)" = 0 ] || { echo "Run as root: curl -fsSL $REPO/setup.sh | sudo sh"; exit 1; }
[ "$(dpkg --print-architecture)" = amd64 ] || { echo "Tibyan packages are amd64 only."; exit 1; }
command -v curl >/dev/null || { apt-get update && apt-get install -y curl ca-certificates; }

# 1. The repository's signing key (fingerprint FC13 3403 7A6C B01E B36B C6ED 38F7 5171 F3BC 0B1B).
curl -fsSL "$REPO/tibyan.gpg" -o "$KEYRING.tmp"
mv "$KEYRING.tmp" "$KEYRING"
chmod 644 "$KEYRING"

# 2. The repository, trusted only with that key.
echo "deb [arch=amd64 signed-by=$KEYRING] $REPO stable main" > "$LIST"

# 3. Refresh the package lists.
apt-get update
echo "Done. Install with: sudo apt install tibyan"
