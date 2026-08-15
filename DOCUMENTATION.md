# Ivors — Dynamic Island for macOS

**Platform:** macOS 14+  |  **Language:** Swift 5.9 · SwiftUI · AppKit  |  **Build:** Swift Package Manager

---

## Table of Contents
1. [Overview](#1-overview)
2. [Requirements](#2-requirements)
3. [Project Structure](#3-project-structure)
4. [Architecture](#4-architecture)
5. [Core Layer](#5-core-layer)
6. [Widget System](#6-widget-system)
7. [Views Layer](#7-views-layer)
8. [Window Management](#8-window-management)
9. [Settings Reference](#9-settings-reference)
10. [Build & Run](#10-build--run)
11. [Adding a New Widget](#11-adding-a-new-widget)
12. [Event System Reference](#12-event-system-reference)
13. [Design Decisions](#13-design-decisions)

---

## 1. Overview

**Ivors** brings Apple's iOS Dynamic Island to macOS. It renders a floating interactive pill at the top center of your screen — integrated with the MacBook's physical camera notch — surfacing live system info through a pluggable widget system.

**Key capabilities:**
- 🎵 Live music tracking with album art, playback controls, equalizer animation
- 🔋 Battery level + charging state monitoring
- 🔵 Bluetooth device connect/disconnect alerts
- 🔌 Power adapter plug/unplug notifications
- ⚡ Quick actions (mic mute, screenshot, dark mode, display lock)
- 📋 Clipboard history
- 🌐 Network / WiFi status
- ⏱️ Timer widget
- 🌤️ Weather overview
- 🖥️ Developer info (CPU / RAM)
- 📅 Calendar & clock widgets

---

## 2. Requirements

| | Version |
|---|---|
| macOS | 14.0 Sonoma+ |
| Swift | 5.9+ |
| Hardware | Any Mac (notch-aware on Apple Silicon MacBooks) |

> [!NOTE]
> Runs as **LSUIElement** — no Dock icon. Controlled via ✦ sparkles menu bar icon.

---

## 3. Project Structure

```
Ivors/
├── Package.swift
├── scripts/build_app.sh          # Release .app bundle script
└── Sources/Ivors/
    ├── App/IvorsApp.swift         # @main + AppDelegate
    ├── Core/
    │   ├── AnimationController.swift
    │   ├── EventBus.swift
    │   ├── IslandLayoutEngine.swift
    │   ├── IslandState.swift
    │   ├── VolumeBrightnessHUDManager.swift
    │   └── WidgetManager.swift
    ├── Settings/
    │   ├── SettingsManager.swift
    │   └── SettingsView.swift
    ├── Views/DynamicIslandView.swift
    ├── Widgets/
    │   ├── DynamicIslandWidget.swift   ← Protocol
    │   ├── Battery/BatteryWidget.swift
    │   ├── Music/MusicWidget.swift + MediaManager.swift
    │   ├── QuickActions/QuickActionsWidget.swift
    │   ├── Calendar/ · Clock/ · Clipboard/
    │   ├── Connectivity/ · Developer/ · Timer/ · Weather/
    │   └── Bluetooth/ · HUD/ · Utility/
    └── Window/
        ├── DynamicIslandPanel.swift
        └── WindowManager.swift
```

---

## 4. Architecture

```
System Events (Battery · BT · Media · Volume)
           │
           ▼
       EventBus  ──────────────────────────────────────┐
    (Combine pub/sub)                                   │
           │                                            │
           ▼                                            ▼
    WidgetManager                              BatteryWidget
  (registry + state)                         (event subscriber)
           │
           ▼
      IslandState
  hidden/minimal/compact/expanded
           │
     ┌─────┴──────┐
     ▼            ▼
WindowManager  DynamicIslandView
 (NSPanel)      (SwiftUI render)
                     │
              Active Widget Views
          compactView / expandedView
```

**Principles:**
- All state flows through `WidgetManager.shared.activeState`
- `EventBus` is the only inter-module communication channel
- Widgets never reference each other directly
- All UI on main thread; background work on `DispatchQueue.global`

---

## 5. Core Layer

### IslandState

Four visual states:

| State | Description |
|---|---|
| `.hidden` | Fully behind camera notch |
| `.minimal` | Same physical position, logically idle |
| `.compact` | Pill visible with widget content on both sides of notch |
| `.expanded` | Full card with detailed widget view + tab bar |

Each state has computed `cornerRadius`, `defaultSize`, `opacity`, `shadowRadius`.

---

### WidgetManager

Singleton: `WidgetManager.shared`

**Key published properties:**

| Property | Type | Description |
|---|---|---|
| `registeredWidgets` | `[DynamicIslandWidget]` | All registered widgets |
| `activeWidget` | `DynamicIslandWidget?` | Left-side primary widget |
| `secondaryWidget` | `DynamicIslandWidget?` | Right-side secondary widget |
| `activeState` | `IslandState` | Current island state |
| `isTemporaryPopupActive` | `Bool` | True during event notifications |

**Key methods:**
```swift
WidgetManager.shared.registerAll([...])
WidgetManager.shared.setPrimaryWidget("music")
WidgetManager.shared.switchToNextWidget()
WidgetManager.shared.triggerTemporaryPopup(widgetId: "battery", duration: 3.0)
WidgetManager.shared.sortAndEvaluateActiveWidget()
```

**State rules:**
- Music playing OR `alwaysShowCompactBar` ON → `.compact`
- Otherwise → `.minimal`
- Event popup always forces `.compact`

---

### EventBus

Combine-backed pub/sub. `EventBus.shared`

```swift
// Post
EventBus.shared.post(.customNotification(title: "Done", message: "file saved", icon: "checkmark.circle.fill", type: .success))

// Subscribe
EventBus.shared.publisher
    .receive(on: DispatchQueue.main)
    .sink { event in ... }
    .store(in: &cancellables)
```

**SystemEvent cases:**

| Event | Payload |
|---|---|
| `.mediaStateChanged` | — |
| `.batteryStateChanged` | `level: Int, isCharging: Bool` |
| `.bluetoothDeviceConnected` | `name: String` |
| `.volumeChanged` | `level: Float` |
| `.brightnessChanged` | `level: Float` |
| `.customNotification` | `title, message, icon, type` |
| `.clipboardUpdated` | `text: String` |
| `.focusModeChanged` | `enabled, name` |
| `.wifiStatusChanged` | `connected, ssid` |

**NotificationType:** `.info` · `.success` · `.warning` · `.error`

---

### IslandLayoutEngine

Detects physical notch geometry and produces pixel-perfect `NSRect` frames.

```swift
IslandLayoutEngine.shared.hasNotch        // Bool
IslandLayoutEngine.shared.notchWidth      // CGFloat
IslandLayoutEngine.shared.notchHeight     // CGFloat
IslandLayoutEngine.expandedWidth          // 350pt (constant)
IslandLayoutEngine.expandedContentHeight  // 180pt (constant)
```

Notch width formula:
```
notchWidth = screen.width − (leftAuxiliaryArea.width + rightAuxiliaryArea.width)
```

Panel frames always anchor the **top edge** to `screen.maxY` and expand downward.

---

### AnimationController

Shared spring presets for 120Hz ProMotion:

```swift
AnimationController.defaultSpring     // snappy(0.22s) — most transitions
AnimationController.interactiveSpring // hover & drag responses
AnimationController.bouncyPop         // notification pop-ins
AnimationController.morphingSpring    // width/height resizing
```

---

### VolumeBrightnessHUDManager

Uses native macOS `AudioObjectAddPropertyListenerBlock` for zero-overhead, instant (0ms delay) volume HUD event triggers.

- **2.0% volume threshold** — detects system volume changes instantly without polling loops
- **0.5s display brightness check** — lightweight background check for display brightness adjustments
- **Suppressed** while `isTemporaryPopupActive == true`
- When triggered: temporarily wakes island to `.compact` for **1.5s**, then returns to previous state
- No intrusive icon or bar shown — just the island waking to signal the change

---

## 6. Widget System

### DynamicIslandWidget Protocol

```swift
public protocol DynamicIslandWidget: AnyObject {
    var id: String { get }
    var name: String { get }
    var priority: Int { get }           // Higher = shown first
    var isVisible: Bool { get }
    var preferredCompactWidth: CGFloat { get }
    var preferredExpandedSize: CGSize { get }

    func compactView() -> AnyView       // ≤36pt height strip
    func expandedView() -> AnyView      // 120pt content area
    func minimalView() -> AnyView

    func onShow(); func onHide()        // Optional lifecycle (default no-op)
    func update(); func reset()
}
```

---

### Built-in Widgets

| ID | Priority | Class | Description |
|---|---|---|---|
| `music` | 200 (playing) | `MusicWidget` | Now Playing, artwork, equalizer, controls |
| `battery` | 150 (event) / 90 | `BatteryWidget` | Level, charging state, event notifications |
| `timer` | 80 | `TimerWidget` | Countdown / stopwatch |
| `calendar` | 70 | `CalendarWidget` | Date, upcoming events |
| `clock` | 65 | `ClockWidget` | Live time display |
| `quick_actions` | 50 | `QuickActionsWidget` | Mic, screenshot, dark mode, lock |
| `connectivity` | 55 | `ConnectivityWidget` | WiFi SSID, signal |
| `clipboard` | 45 | `ClipboardWidget` | Recent clipboard entries |
| `weather` | 40 | `WeatherWidget` | Temperature, condition |

> [!IMPORTANT]
> `BatteryWidget.priority` is dynamic — `150` while showing a notification popup, `90` otherwise — ensuring charger/Bluetooth alerts always surface above normal widgets.

---

## 7. Views Layer

### DynamicIslandView

Main SwiftUI view inside the floating panel.

#### Compact Layout (Notch Mac)
```
┌──────────────┬─── notch ───┬──────────────────┐
│  LEFT SIDE   │  [camera]   │   RIGHT SIDE      │
│ Always music │   notch     │ Switching widget  │
│ if playing,  │   area      │ (battery, clock,  │
│ else active  │             │  weather, etc.)   │
└──────────────┴─────────────┴──────────────────┘
```

**Left side priority:** music if playing → active widget  
**Right side priority:** current switching widget → audio equalizer → secondary → accessory

#### Expanded Layout
- Header: widget icon + name · "Keep Bar Visible" toggle
- Content: `widget.expandedView()` at 120pt
- Trackpad 2-finger swipe to navigate widgets
- Bottom icon tab bar for all enabled widgets

#### Startup Animation
```swift
// Glides up from below into camera notch on launch
startupOffsetY: 24pt → 0pt
startupScale: 0.88 → 1.0
// spring(response: 0.65, dampingFraction: 0.72)
```

---

### NotchIslandShape

Custom `Shape` with mathematically exact concave outer corners (Bézier) and convex inner corners (circular arcs) matching Apple's physical notch geometry.

Parameters:
- `topOutsideRadius` — outer flare (8pt notch / 4pt notchless)
- `bottomRadius` — bottom inner corner (16pt compact / 32pt expanded)

---

## 8. Window Management

**Files:** `WindowManager.swift`, `DynamicIslandPanel.swift`

`NSPanel` configuration:
- `level = .screenSaver + 1` — above all windows including full-screen apps
- `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`
- Transparent background, no title bar, no shadow
- Click-through when compact/minimal

`WindowManager` observes `activeState` and calls `IslandLayoutEngine.calculatePanelFrame()` → resizes panel with `NSAnimationContext` smooth transitions.

---

## 9. Settings Reference

All settings persist via `@AppStorage` (UserDefaults). Access: `SettingsManager.shared`

| Key | Type | Default | Description |
|---|---|---|---|
| `launchAtLogin` | Bool | false | SMAppService login item |
| `accentColorName` | String | "Orange" | Accent color (Orange/Blue/Purple/Pink/Green/Red/Yellow/White) |
| `islandScale` | Double | 1.0 | Global island scale factor |
| `animationSpeed` | Double | 1.0 | Animation speed multiplier |
| `blurIntensity` | Double | 1.0 | Background opacity (0=glass, 1=solid black) |
| `autoHideDelay` | Double | 1.2 | Seconds before collapse after hover leaves |
| `enableHoverExpand` | Bool | true | Expand on mouse hover |
| `enableClickToggle` | Bool | true | Click to toggle expanded/compact |
| `duoWidgetMode` | Bool | true | Show secondary widget on right side |
| `alwaysShowCompactBar` | Bool | false | Keep bar visible when music paused |
| `razorpayPaymentPageURL` | String | "https://ivors.app/checkout" | Razorpay checkout webpage link for license purchases |

**Per-widget enable/disable:**
```swift
SettingsManager.shared.isWidgetEnabled("clipboard")            // Bool
SettingsManager.shared.setWidgetEnabled("weather", enabled: false)
```

### Razorpay Payment & License Key Activation Flow

1. **Purchase**: Users click **"Buy on Razorpay"** in `Settings -> Account`. This opens the configured Razorpay Payment Page (`razorpayPaymentPageURL`).
2. **Key Generation & Delivery**: Upon payment completion on the Razorpay webpage, users are issued an Ivors Pro License Key (Format: `IVORS-PRO-XXXX-YYYY-ZZZZ`).
3. **Activation**: Users paste their License Key in `Settings -> Account` and click **"Activate Key"**. `SecurityGuard.shared.validateLicenseKeyFormat` verifies the key format and `TrialManager.shared.activateLicense` permanently activates Pro mode in macOS Keychain.

---

## 10. Build & Run

### Debug
```bash
swift build
swift run
```

### Release .app Bundle
```bash
./scripts/build_app.sh
open Ivors.app
```

### Permissions (runtime)
| Permission | Used For |
|---|---|
| Accessibility (optional) | AppleScript Now Playing bridge |
| Microphone | Quick Actions mic mute |
| Screen Recording (optional) | Screenshot quick action |

> [!WARNING]
> SPM builds do not include a signed `Info.plist`. For distribution, add the app target to an Xcode project and include `NSMicrophoneUsageDescription` and `NSAppleEventsUsageDescription` keys.

---

## 11. Adding a New Widget

**Step 1** — Create `Sources/Ivors/Widgets/MyWidget/MyWidget.swift`:

```swift
import SwiftUI

public final class MyWidget: DynamicIslandWidget, ObservableObject {
    public let id: String = "my_widget"
    public let name: String = "My Widget"
    public let priority: Int = 60
    public var isVisible: Bool { true }

    public init() {}

    public func compactView() -> AnyView {
        AnyView(
            HStack(spacing: 6) {
                Image(systemName: "star.fill").foregroundColor(.yellow)
                Text("My Widget")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
            }
        )
    }

    public func expandedView() -> AnyView {
        AnyView(Text("Expanded content").foregroundColor(.white).padding())
    }

    public func minimalView() -> AnyView {
        AnyView(Image(systemName: "star.fill").foregroundColor(.yellow))
    }
}
```

**Step 2** — Register in `IvorsApp.swift`:
```swift
WidgetManager.shared.registerAll([
    MusicWidget(), BatteryWidget(), ..., MyWidget()
])
```

**Step 3** — Add to tab bar in `DynamicIslandView.swift`:
```swift
let mainWidgetIds = ["music", "battery", ..., "my_widget"]
```

**Step 4** — Add icon and title mappings in `DynamicIslandView.swift`:
```swift
// widgetIconName()
case "my_widget": return "star.fill"

// widgetShortTitle()
case "my_widget": return "My Widget"
```

---

## 12. Event System Reference

### Show a custom notification
```swift
EventBus.shared.post(.customNotification(
    title: "Download Complete",
    message: "video.mp4 saved",
    icon: "checkmark.circle.fill",
    type: .success
))
```

This automatically:
1. Switches active widget to `BatteryWidget` (notification handler)
2. Shows badge on left side of notch for 3 seconds
3. Suppresses volume/brightness HUD during popup
4. Restores previous widget after timer expires

### Subscribe from a Widget
```swift
private var cancellables = Set<AnyCancellable>()

EventBus.shared.publisher
    .receive(on: DispatchQueue.main)
    .sink { [weak self] event in
        if case .wifiStatusChanged(let connected, let ssid) = event {
            self?.isConnected = connected
            self?.ssid = ssid
        }
    }
    .store(in: &cancellables)
```

---

## 13. Design Decisions

### No half-expanded state
An earlier iteration had a `.halfExpanded` state showing a volume/brightness bar on every function key press. Removed because:
- Constant expand/contract on every volume keypress was distracting
- macOS already has a native volume/brightness OSD overlay
- The current 1.5s silent island wakeup is less intrusive

### Music always pinned to the left
The camera notch naturally creates a left/right split. Left = primary anchor (music — the most persistent, time-sensitive info). Right = secondary slot the user cycles through freely without losing song context.

### NSPanel over NSWindow
`NSPanel` supports `collectionBehavior` flags (`.canJoinAllSpaces`, `.fullScreenAuxiliary`) needed to float above full-screen apps and across all Spaces — matching iOS Dynamic Island behavior.

### Notch geometry detection
```
notchWidth = screen.width − (leftAuxiliaryArea.width + rightAuxiliaryArea.width)
```
Uses `screen.auxiliaryTopLeftArea` / `auxiliaryTopRightArea` — no hardcoded dimensions.
