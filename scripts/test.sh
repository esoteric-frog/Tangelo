#!/bin/bash
# swift test; on Command Line Tools (no Xcode) point at the CLT Testing.framework.
set -euo pipefail
cd "$(dirname "$0")/.."
[ -x vendor/bin/cwebp ] || scripts/fetch-tools.sh
if xcode-select -p | grep -q CommandLineTools; then
  F=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
  L=/Library/Developer/CommandLineTools/Library/Developer/usr/lib
  exec swift test -Xswiftc -F -Xswiftc "$F" -Xlinker -F -Xlinker "$F" \
    -Xlinker -rpath -Xlinker "$F" -Xlinker -rpath -Xlinker "$L" "$@"
fi
exec swift test "$@"
