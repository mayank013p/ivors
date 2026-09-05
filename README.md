# 🏝️ Ivors — Dynamic Island for macOS

[![macOS](https://img.shields.io/badge/macOS-14.0%2B%20Sonoma%20%7C%20Sequoia-black?style=flat&logo=apple)](https://github.com/mayank013p/ivors)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange?style=flat&logo=swift)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Homebrew](https://img.shields.io/badge/Homebrew-Cask-orange?style=flat&logo=homebrew)](https://brew.sh)

**Ivors** brings the iOS Dynamic Island experience natively to macOS. Built entirely with Swift and SwiftUI, it creates a fluid, interactive notch HUD for live music tracking, hardware stats, notifications, clipboard history, file stashing, and productivity tools.

---

## ⚡ Quick Install

### Option 1: 🍺 Homebrew Cask (Recommended)
Automatically manages installation, updates, and uninstallation without Gatekeeper popups:

```bash
brew tap mayank013p/ivors https://github.com/mayank013p/ivors && brew install --cask ivors
```

### Option 2: ⚡ Direct Terminal 1-Liner
Downloads, extracts to `/Applications`, strips quarantine flags, and starts Ivors immediately:

```bash
curl -fsSL https://raw.githubusercontent.com/mayank013p/ivors/main/install.sh | bash
```

### Option 3: 💿 Disk Image (.dmg) or Package (.pkg)
Download directly from GitHub Releases or the official site:
- **[Download Ivors-v1.4.0.dmg](https://raw.githubusercontent.com/mayank013p/ivors/main/Ivors-v1.4.0.dmg)**
- **[Download Ivors-v1.4.0.pkg](https://raw.githubusercontent.com/mayank013p/ivors/main/Ivors-v1.4.0.pkg)**

---

## 🗑️ Complete Uninstallation Guide

### Method 1: 🍺 Homebrew Uninstall (Clean & Automated)
Gracefully quits the running app and removes all files:

```bash
brew uninstall --cask ivors
```

### Method 2: ⚡ Clean Uninstaller Script (Removes App, Cache, & Preferences)
Runs a deep cleanup of all files and preferences:

```bash
curl -fsSL https://raw.githubusercontent.com/mayank013p/ivors/main/scripts/uninstall.sh | bash
```

### Method 3: 🖱️ In-App 1-Click Clean Uninstaller
1. Click the **✦ Ivors sparkles icon** in your macOS Menu Bar (or open **Ivors Preferences** -> **About** tab).
2. Click **"Uninstall Ivors..."**.
3. Confirm in the dialog — Ivors will cleanly remove all application data and terminate.

### Method 4: 🛠️ Manual Terminal Command
```bash
killall Ivors 2>/dev/null; brew uninstall --cask ivors 2>/dev/null; rm -rf /Applications/Ivors.app ~/Library/Application\ Support/Ivors ~/Library/Preferences/com.mayank.ivors.plist ~/Library/Saved\ Application\ State/com.mayank.ivors.savedState
```

---

## 🔄 Reinstalling & Updating

### To Update to the Latest Version:
```bash
brew upgrade --cask ivors
```

### To Force a Clean Reinstallation:
```bash
brew reinstall --cask ivors --force && open /Applications/Ivors.app
```

---

## 🎮 Shortcuts & Controls

| Shortcut / Action | Function |
|---|---|
| **⌥ Option + Space** | Global shortcut to toggle the Dynamic Island |
| **Hover on Notch** | Expands the Dynamic Island |
| **Two-Finger Horizontal Swipe** | Swipe left/right over the island to switch widgets |
| **Drag & Drop any File** | Drops file into the built-in File Stash Shelf |
| **Click Menu Bar Icon (✦)** | Opens quick actions, widget toggles, preferences, and quit |
| **ESC key** | Collapses the expanded island |

---

## 🛡️ macOS Permissions & Privacy

Ivors uses official macOS native APIs to provide real-time status widgets. On first launch, macOS may prompt for:
- **Bluetooth**: To display AirPods/peripheral battery levels and connectivity.
- **Apple Events / Automation**: To control Apple Music and Spotify playback.
- **Microphone**: For the privacy indicator and 1-click mute widget (Ivors never records or transmits audio).
- **Accessibility**: For global shortcuts (⌥ Space) and notch drag-and-drop targeting.

All application logic is 100% open-source and auditable.

---

## 🛠️ Building from Source

Requirements: macOS 14.0+, Xcode 15+ / Swift 5.9+.

```bash
# Clone the repository
git clone https://github.com/mayank013p/ivors.git
cd ivors

# Build Release App Bundle
bash scripts/build_app.sh

# Launch App
open Ivors.app
```
