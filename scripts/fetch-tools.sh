#!/bin/bash
# Download standalone tools into vendor/bin and verify their checksums.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p vendor/bin vendor/licenses
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

url=https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-1.6.0-mac-arm64.tar.gz
sha=bc6bf84cc70f3f8574fba797d1e4a7dea4feebe9fa4be919f202413ea2b3b8f2
curl -fsSL "$url" -o "$tmp/webp.tgz"
echo "$sha  $tmp/webp.tgz" | shasum -a 256 -c -
tar xzf "$tmp/webp.tgz" -C "$tmp"
cp "$tmp/libwebp-1.6.0-mac-arm64/bin/cwebp" vendor/bin/
# The binary tarball ships no COPYING file; record the license and its source.
echo "libwebp 1.6.0 (cwebp): BSD 3-Clause. https://chromium.googlesource.com/webm/libwebp/+/refs/tags/v1.6.0/COPYING" > vendor/licenses/libwebp.txt
echo "tools ready in vendor/bin"
