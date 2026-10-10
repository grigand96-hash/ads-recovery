#!/bin/bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "$0")/.." && pwd)
OUT="${BUILD_DIR:-$ROOT/build}"
xcrun swift "$ROOT/Scripts/DMGBackground.swift" "$OUT/installer-background.png"
"${DMGBUILD:-dmgbuild}" -s "$ROOT/Scripts/dmg-settings.py" -D "out=$OUT" 'Ads Recovery' "$OUT/Ads-Recovery-macOS.dmg"
hdiutil verify "$OUT/Ads-Recovery-macOS.dmg"
(cd "$OUT" && shasum -a 256 Ads-Recovery-macOS.dmg Ads-Recovery-macOS.zip > SHA256SUMS.txt)
