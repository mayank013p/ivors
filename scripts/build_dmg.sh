#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$PROJECT_DIR/Ivors.app"
DMG_NAME="Ivors-v1.4.0.dmg"
DMG_PATH="$PROJECT_DIR/$DMG_NAME"
TEMP_DMG="$PROJECT_DIR/.build/temp.dmg"

echo "🚀 Building Ivors Release App Bundle..."
bash "$PROJECT_DIR/scripts/build_app.sh"

echo "💿 Creating temporary read-write disk image..."
rm -f "$TEMP_DMG" "$DMG_PATH"

# 1. Create temporary read-write DMG (HFS+ for full icon attribute compatibility)
hdiutil create -size 40m -fs HFS+ -volname "Ivors" -type UDIF "$TEMP_DMG"

# 2. Mount temporary DMG
MOUNT_DIR=$(hdiutil attach -readwrite -noverify -noautoopen "$TEMP_DMG" | grep '/Volumes/' | sed 's/.*\/Volumes\//\/Volumes\//')

echo "📂 Copying files to mounted volume ($MOUNT_DIR)..."
cp -R "$APP_DIR" "$MOUNT_DIR/Ivors.app"
ln -s /Applications "$MOUNT_DIR/Applications"

# Set Native Finder Icon on Ivors.app inside mounted DMG volume
swift -e 'import Cocoa; if let img = NSImage(contentsOfFile: "/Users/mayank/Documents/ivors-website/public/ivors_logo.png") { NSWorkspace.shared.setIcon(img, forFile: "'"$MOUNT_DIR"'/Ivors.app", options: []) }' 2>/dev/null || true

# 3. Attach Custom Volume Icon on Mounted DMG Volume
if [ -f "$PROJECT_DIR/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/AppIcon.icns" "$MOUNT_DIR/.VolumeIcon.icns"
    SetFile -c icnC "$MOUNT_DIR/.VolumeIcon.icns" 2>/dev/null || true
    SetFile -a C "$MOUNT_DIR" 2>/dev/null || true
fi

# 4. Sync & Unmount
sync
hdiutil detach "$MOUNT_DIR"

# 5. Convert temporary DMG to compressed read-only installer (UDZO)
echo "🔏 Converting to compressed final DMG installer ($DMG_NAME)..."
hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH"

rm -f "$TEMP_DMG"

echo "✅ Gold Standard macOS Installer Created Successfully!"
echo "📍 Location: $DMG_PATH"
ls -lh "$DMG_PATH"
