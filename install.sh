#!/bin/bash
set -e

echo "🚀 Installing Ivors Dynamic Island..."

INSTALL_DIR="/Applications"
APP_PATH="$INSTALL_DIR/Ivors.app"
ZIP_URL="https://raw.githubusercontent.com/mayank013p/ivors_web/main/public/downloads/Ivors-macOS.zip"

TMP_ZIP="/tmp/Ivors-macOS.zip"

echo "📥 Downloading latest Ivors release..."
curl -fsSL "$ZIP_URL" -o "$TMP_ZIP"

echo "📦 Extracting to /Applications..."
rm -rf "$APP_PATH"
unzip -q "$TMP_ZIP" -d "$INSTALL_DIR"
rm -f "$TMP_ZIP"

echo "🛡️ Removing quarantine flags for seamless execution..."
xattr -cr "$APP_PATH" 2>/dev/null || true

echo "✅ Ivors installed successfully! Launching now..."
open "$APP_PATH"
