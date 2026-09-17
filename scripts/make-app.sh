#!/bin/sh
# Builds a release binary and wraps it in build/Sample Search.app (ad-hoc signed).
set -eu
cd "$(dirname "$0")/.."
swift build -c release --product SampleSearch >/dev/null
EXE=".build/release/SampleSearch"
VERSION=$(cat VERSION)
BUILD_NUMBER=$(git rev-list --count HEAD 2>/dev/null || echo 1)
APP="build/Sample Search.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$EXE" "$APP/Contents/MacOS/Sample Search"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key><string>en</string>
	<key>CFBundleExecutable</key><string>Sample Search</string>
	<key>CFBundleIconFile</key><string>AppIcon</string>
	<key>CFBundleIdentifier</key><string>com.pluginfox.samplesearch</string>
	<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
	<key>CFBundleName</key><string>Sample Search</string>
	<key>CFBundleDisplayName</key><string>Sample Search</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>$VERSION</string>
	<key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
	<key>LSMinimumSystemVersion</key><string>14.0</string>
	<key>LSApplicationCategoryType</key><string>public.app-category.music</string>
	<key>NSHighResolutionCapable</key><true/>
	<key>NSHumanReadableCopyright</key><string>© $(date +%Y) Pluginfox</string>
</dict>
</plist>
PLIST
printf 'APPL????' > "$APP/Contents/PkgInfo"
codesign --force --sign - "$APP" >/dev/null 2>&1 || true
echo "Built $APP"
if [ "${1:-}" = "--install" ]; then
    DEST="/Applications/Sample Search.app"
    osascript -e 'tell application "Sample Search" to quit' >/dev/null 2>&1 || true
    osascript -e 'tell application "Trigger Search" to quit' >/dev/null 2>&1 || true
    rm -rf "$DEST" "/Applications/Trigger Search.app"   # the app's previous name
    cp -R "$APP" "$DEST"
    echo "Installed $DEST"
fi
