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
    <string>AppIcon.icns</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.mayank.ivors</string>
    <key>CFBundleName</key>
    <string>Ivors</string>
    <key>CFBundleDisplayName</key>
    <string>Ivors</string>
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

# Set native Finder icon attribute on app bundle
swift -e 'import Cocoa; if let img = NSImage(contentsOfFile: "/Users/mayank/Documents/ivors-website/public/ivors_logo.png") { NSWorkspace.shared.setIcon(img, forFile: "'"$APP_DIR"'", options: []) }' 2>/dev/null || true
SetFile -a C "$APP_DIR" 2>/dev/null || true

# Apply ad-hoc signature with hardened runtime enabled (MUST BE LAST!)
echo "🔏 Applying Hardened Runtime code signature..."
codesign --force --deep --options runtime -s - "$APP_DIR" 2>/dev/null || true
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_DIR" 2>/dev/null || true

echo "✅ Hardened App bundle created at $APP_DIR"

