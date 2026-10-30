#!/usr/bin/env bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
cd "$DIR"

echo "🔨 Building Morph binary..."
swift build -c release

TMP_APP_DIR="/tmp/Morph.app"
APP_DIR="$DIR/Morph.app"
CONTENTS_DIR="$TMP_APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "📦 Assembling Morph.app bundle in /tmp..."
rm -rf "$TMP_APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy binary
cp "$DIR/.build/release/morph" "$MACOS_DIR/morph"
chmod +x "$MACOS_DIR/morph"

# Copy resources
if [ -d "$DIR/Resources" ]; then
    cp -R "$DIR/Resources/"* "$RESOURCES_DIR/" 2>/dev/null || true
fi

# Write Info.plist
cat << 'EOF' > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>morph</string>
    <key>CFBundleIdentifier</key>
    <string>com.morph.notch</string>
    <key>CFBundleName</key>
    <string>Morph</string>
    <key>CFBundleDisplayName</key>
    <string>Morph</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSCalendarsUsageDescription</key>
    <string>Morph accesses your calendar to display upcoming meetings and events directly in the Dynamic Notch.</string>
    <key>NSCalendarsFullAccessUsageDescription</key>
    <string>Morph accesses your calendar to display upcoming meetings and events directly in the Dynamic Notch.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>Morph interacts with web browsers to detect active forms and applications.</string>
    <key>NSAccessibilityUsageDescription</key>
    <string>Morph uses accessibility to track and detect forms across desktop applications.</string>
</dict>
</plist>
EOF

echo "🔏 Signing Morph.app bundle in /tmp..."
find "$TMP_APP_DIR" -name ".DS_Store" -delete 2>/dev/null || true
dot_clean "$TMP_APP_DIR" 2>/dev/null || true
xattr -cr "$TMP_APP_DIR" 2>/dev/null || true

SIGN_IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | grep "Apple Development" | head -n 1 | awk -F '"' '{print $2}')
if [ -n "$SIGN_IDENTITY" ]; then
    echo "🔏 Signing with identity: $SIGN_IDENTITY"
    codesign --force --deep --sign "$SIGN_IDENTITY" "$TMP_APP_DIR"
else
    echo "🔏 Signing with ad-hoc signature (-)"
    codesign --force --deep --sign - "$TMP_APP_DIR"
fi

echo "✅ Morph.app built successfully at: $TMP_APP_DIR"

# Install into /Applications
echo "🚀 Installing Morph.app to /Applications/Morph.app..."
rm -rf "/Applications/Morph.app"
cp -R "$TMP_APP_DIR" "/Applications/Morph.app"
echo "✅ Morph.app successfully installed to /Applications/Morph.app"

# Mirror to local directory
rm -rf "$APP_DIR"
cp -R "$TMP_APP_DIR" "$APP_DIR"
