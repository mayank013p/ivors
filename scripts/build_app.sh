#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/.build/release"
APP_DIR="$PROJECT_DIR/Ivors.app"

echo "🔨 Building Ivors in Hardened Release Mode..."
cd "$PROJECT_DIR"
swift build -c release -Xswiftc -O -Xswiftc -wmo -Xlinker -dead_strip

echo "📦 Creating Ivors.app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BUILD_DIR/Ivors" "$APP_DIR/Contents/MacOS/Ivors"
if [ -f "$PROJECT_DIR/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

# Strip symbols from release executable to prevent reverse engineering
echo "🛡️ Stripping symbols from binary..."
strip -s "$APP_DIR/Contents/MacOS/Ivors" 2>/dev/null || true

cat <<EOF > "$APP_DIR/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Ivors</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.ivors.dynamicisland</string>
    <key>CFBundleName</key>
    <string>Ivors Dynamic Island</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
</dict>
</plist>
EOF

chmod +x "$APP_DIR/Contents/MacOS/Ivors"

# Apply ad-hoc signature with hardened runtime enabled
echo "🔏 Applying Hardened Runtime code signature..."
codesign --force --options runtime -s - "$APP_DIR" 2>/dev/null || true
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_DIR" 2>/dev/null || true

echo "✅ Hardened App bundle created at $APP_DIR"

