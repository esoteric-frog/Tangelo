#!/bin/bash
# Build build/Tangelo.app with bundled tools, ad-hoc signed.
set -euo pipefail
cd "$(dirname "$0")/.."
[ -x vendor/bin/cwebp ] || scripts/fetch-tools.sh
swift build -c release --product Tangelo
APP=build/Tangelo.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/bin" "$APP/Contents/Resources/licenses"
cp "$(swift build -c release --show-bin-path)/Tangelo" "$APP/Contents/MacOS/"
cp vendor/bin/* "$APP/Contents/Resources/bin/"
cp vendor/licenses/* "$APP/Contents/Resources/licenses/"
cp Resources/Info.plist "$APP/Contents/"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
codesign --force --deep --sign - "$APP"
echo "Built $APP"
