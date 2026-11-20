#!/usr/bin/env bash
# ============================================================================
# Download Monaco locally so the browser diff works offline.
#
# Fetches the monaco-editor npm package, verifies it against the registry's
# SHA-512 integrity hash, and unpacks only the runtime (min/vs, ~14 MB) into
# tools/monaco-diff/vendor/monaco/. That folder is gitignored; run this script
# once on each machine. server.js uses it automatically when present and falls
# back to the jsDelivr CDN when it is not.
#
# Usage: tools/monaco-diff/install.sh [version]     (default below)
# ============================================================================
set -euo pipefail

VERSION="${1:-0.52.2}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dest="$here/vendor/monaco"

for tool in npm tar openssl; do
  command -v "$tool" >/dev/null || { echo "install.sh: '$tool' not found on PATH" >&2; exit 1; }
done

if [ -f "$dest/VERSION" ] && [ "$(cat "$dest/VERSION")" = "$VERSION" ] && [ -f "$dest/vs/loader.js" ]; then
  echo "Monaco $VERSION already installed at $dest"
  exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cd "$tmp"

echo "Downloading monaco-editor@$VERSION ..."
npm pack "monaco-editor@$VERSION" --silent >/dev/null
tgz="monaco-editor-$VERSION.tgz"

# Verify the tarball against the hash the registry publishes for this version.
expected="$(npm view "monaco-editor@$VERSION" dist.integrity)"
actual="sha512-$(openssl dgst -sha512 -binary "$tgz" | base64 -w0)"
if [ "$expected" != "$actual" ]; then
  echo "install.sh: integrity check FAILED" >&2
  echo "  expected: $expected" >&2
  echo "  actual:   $actual" >&2
  exit 1
fi
echo "Integrity OK ($actual)" | cut -c1-60

tar -xzf "$tgz" package/min/vs package/LICENSE package/ThirdPartyNotices.txt

rm -rf "$dest"
mkdir -p "$dest"
mv package/min/vs "$dest/vs"
cp package/LICENSE package/ThirdPartyNotices.txt "$dest/"
echo "$VERSION" > "$dest/VERSION"

echo "Installed Monaco $VERSION -> $dest ($(du -sh "$dest" | cut -f1))"
