#!/bin/bash
# Ivors Complete Clean Uninstaller
set -e

echo "🧹 Terminating Ivors processes..."
killall Ivors 2>/dev/null || true

echo "🗑️ Removing Ivors Homebrew Cask (if present)..."
brew uninstall --cask ivors 2>/dev/null || true

echo "🗑️ Removing Ivors application bundles..."
rm -rf /Applications/Ivors.app ~/Applications/Ivors.app 2>/dev/null || true

echo "🧹 Cleaning up preferences and application cache..."
rm -rf ~/Library/Application\ Support/Ivors 2>/dev/null || true
rm -rf ~/Library/Preferences/com.mayank.ivors.plist 2>/dev/null || true
rm -rf ~/Library/Saved\ Application\ State/com.mayank.ivors.savedState 2>/dev/null || true
rm -rf ~/Library/Caches/com.mayank.ivors 2>/dev/null || true

echo "✅ Ivors has been completely and cleanly uninstalled from your Mac."
