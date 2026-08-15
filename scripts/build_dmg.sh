#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$PROJECT_DIR/Ivors.app"
DMG_NAME="Ivors-v1.4.0.dmg"
DMG_PATH="$PROJECT_DIR/$DMG_NAME"
STAGING_DIR="$PROJECT_DIR/.build/dmg_staging"

echo "🚀 Building Ivors Release App Bundle..."
bash "$PROJECT_DIR/scripts/build_app.sh"

echo "💿 Preparing DMG Staging Area..."
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

# Copy Ivors.app to staging
cp -R "$APP_DIR" "$STAGING_DIR/Ivors.app"

# Attach Volume Icon so DMG installer shows custom logo in Finder & browser downloads
if [ -f "$PROJECT_DIR/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/AppIcon.icns" "$STAGING_DIR/.VolumeIcon.icns"
    SetFile -c icnC "$STAGING_DIR/.VolumeIcon.icns" 2>/dev/null || true
    SetFile -a C "$STAGING_DIR" 2>/dev/null || true
fi

# Create symlink to /Applications for standard drag-and-drop macOS installer
ln -s /Applications "$STAGING_DIR/Applications"

echo "🔏 Creating macOS .dmg Disk Image ($DMG_NAME)..."
rm -f "$DMG_PATH"

hdiutil create \
  -volname "Ivors Dynamic Island" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

rm -rf "$STAGING_DIR"

echo "✅ Gold Standard macOS Installer Created Successfully!"
echo "📍 Location: $DMG_PATH"
ls -lh "$DMG_PATH"
