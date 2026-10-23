#!/bin/bash
# Build, copy to /Applications, and start. The app adds itself to Login Items on launch.
set -euo pipefail
cd "$(dirname "$0")/.."
scripts/make-app.sh
pkill -x Tangelo || true
rm -rf /Applications/Tangelo.app
cp -R build/Tangelo.app /Applications/
open /Applications/Tangelo.app
echo "Installed /Applications/Tangelo.app"
