#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$PROJECT_DIR/Ivors.app"
PKG_NAME="Ivors-v1.4.0.pkg"
PKG_PATH="$PROJECT_DIR/$PKG_NAME"
SCRIPTS_DIR="$PROJECT_DIR/.build/pkg_scripts"

echo "🔨 Building Ivors.app first..."
bash "$PROJECT_DIR/scripts/build_app.sh"

echo "📦 Creating PKG installer package with auto-quarantine stripping..."
rm -rf "$SCRIPTS_DIR"
mkdir -p "$SCRIPTS_DIR"

cat <<'EOF' > "$SCRIPTS_DIR/postinstall"
#!/bin/bash
# Remove quarantine attributes from installed Ivors.app
xattr -cr /Applications/Ivors.app 2>/dev/null || true
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/Ivors.app 2>/dev/null || true
# Launch Ivors automatically
open /Applications/Ivors.app 2>/dev/null || true
exit 0
EOF

chmod +x "$SCRIPTS_DIR/postinstall"

# Build flat PKG package installer
pkgbuild \
    --component "$APP_DIR" \
    --install-location "/Applications" \
    --scripts "$SCRIPTS_DIR" \
    --identifier "com.mayank.ivors" \
    --version "1.4.0" \
    "$PKG_PATH"

rm -rf "$SCRIPTS_DIR"

echo "✅ Self-clearing PKG Installer created at $PKG_PATH"
