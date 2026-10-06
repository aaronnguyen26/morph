#!/usr/bin/env bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
cd "$DIR"

echo "🔨 Building Morph binary..."
swift build -c release

APP_DIR="$DIR/Morph.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "📦 Assembling Morph.app bundle..."
rm -rf "$APP_DIR"
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
</dict>
</plist>
EOF

echo "✅ Morph.app built successfully at: $APP_DIR"
