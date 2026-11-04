#!/bin/zsh
set -eu

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_BUNDLE="${APP_BUNDLE:-$HOME/Applications/Claude Switcher.app}"
MACOS_DIR="$APP_BUNDLE/Contents/MacOS"
RES_DIR="$APP_BUNDLE/Contents/Resources"
ARCH="$(uname -m)"

mkdir -p "$MACOS_DIR" "$RES_DIR"

cat > "$APP_BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDisplayName</key>
	<string>Claude Switcher</string>
	<key>CFBundleExecutable</key>
	<string>ClaudeSwitcherBar</string>
	<key>CFBundleIconFile</key>
	<string>electron.icns</string>
	<key>CFBundleIdentifier</key>
	<string>io.github.claude-switcher-bar</string>
	<key>CFBundleName</key>
	<string>Claude Switcher</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.1.0</string>
	<key>CFBundleVersion</key>
	<string>2</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSHighResolutionCapable</key>
	<true/>
</dict>
</plist>
PLIST

ICON_SOURCE="${ICON_SOURCE:-/Applications/Claude.app/Contents/Resources/electron.icns}"
if [[ -f "$ICON_SOURCE" ]]; then
  cp -f "$ICON_SOURCE" "$RES_DIR/electron.icns"
fi

echo "Compiling ClaudeSwitcherBar (${ARCH}-apple-macosx14.0, -O)..."
/usr/bin/swiftc \
  -O \
  -parse-as-library \
  -swift-version 5 \
  -target "${ARCH}-apple-macosx14.0" \
  -sdk "$(/usr/bin/xcrun --show-sdk-path)" \
  "$PROJECT_DIR/Sources/ClaudeSwitcherApp.swift" \
  -o "$MACOS_DIR/ClaudeSwitcherBar"

/usr/bin/codesign --force --deep --sign - "$APP_BUNDLE"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_BUNDLE" || true

echo "Built & signed: $APP_BUNDLE"
