#!/bin/bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "$0")/.." && pwd)
OUT="${BUILD_DIR:-$ROOT/build}"
VERSION=$(tr -d '\n' < "$ROOT/VERSION")
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo 'VERSION must use major.minor.patch' >&2; exit 1
fi
if [[ "${GITHUB_REF_TYPE:-}" == tag && "${GITHUB_REF_NAME:-}" != "v$VERSION" ]]; then
  echo 'Git tag must match VERSION' >&2; exit 1
fi
mkdir -p "$OUT/icons" "$OUT/AppIcon.iconset" "$OUT/bin" "$OUT/Ads Recovery.app/Contents/MacOS" "$OUT/Ads Recovery.app/Contents/Resources"
xcrun swift "$ROOT/Scripts/GenerateIcons.swift" "$OUT/icons"
for size in 16 32 128 256 512; do
  cp "$OUT/icons/AppIcon-$size.png" "$OUT/AppIcon.iconset/icon_${size}x${size}.png"
  double=$((size * 2))
  cp "$OUT/icons/AppIcon-$double.png" "$OUT/AppIcon.iconset/icon_${size}x${size}@2x.png"
done
iconutil -c icns "$OUT/AppIcon.iconset" -o "$OUT/Ads Recovery.app/Contents/Resources/AppIcon.icns"
cp "$ROOT/Resources/PAD-mascot.png" "$OUT/icons/AppIcon-128.png" "$OUT/icons/StatusIcon.png" "$OUT/Ads Recovery.app/Contents/Resources/"
xcrun swiftc "$ROOT/Sources/Detector.swift" "$ROOT/Sources/Diagnostics.swift" "$ROOT/Tests/DetectorTests.swift" -o "$OUT/bin/tests"
"$OUT/bin/tests"
ARCHS="${ARCHS:-arm64 x86_64}"
for arch in $ARCHS; do
  xcrun swiftc -swift-version 5 -O -target "$arch-apple-macosx14.0" "$ROOT"/Sources/*.swift -o "$OUT/bin/AdsRecovery-$arch"
done
parts=()
for arch in $ARCHS; do parts+=("$OUT/bin/AdsRecovery-$arch"); done
lipo -create "${parts[@]}" -output "$OUT/Ads Recovery.app/Contents/MacOS/AdsRecovery"
cat > "$OUT/Ads Recovery.app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>AdsRecovery</string>
<key>CFBundleIdentifier</key><string>team.pad.adsrecovery</string>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleName</key><string>Ads Recovery</string>
<key>CFBundleDisplayName</key><string>Ads Recovery</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>CFBundleVersion</key><string>$VERSION</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>LSUIElement</key><true/>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSHumanReadableCopyright</key><string>PAD team</string>
</dict></plist>
PLIST
codesign --force --sign - "$OUT/Ads Recovery.app"
codesign --verify --strict "$OUT/Ads Recovery.app"
plutil -lint "$OUT/Ads Recovery.app/Contents/Info.plist"
ditto -c -k --keepParent "$OUT/Ads Recovery.app" "$OUT/Ads-Recovery-macOS.zip"
(cd "$OUT" && shasum -a 256 Ads-Recovery-macOS.zip > SHA256SUMS.txt)
printf 'Built %s\n' "$OUT/Ads Recovery.app"
