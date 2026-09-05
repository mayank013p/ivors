import SwiftUI
import AppKit

@main
struct IvorsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure app as LSUIElement (runs overlay panel without Dock icon)
        NSApp.setActivationPolicy(.accessory)

        // Register default system widgets (Music first, QuickActions in middle!)
        WidgetManager.shared.registerAll([
            MusicWidget(),
            CommandPaletteWidget(),
            AIUsageWidget(),
            NotchTerminalWidget(),
            ZoomTeleprompterWidget(),
            SyncedLyricsWidget(),
            SystemStatsWidget(),
            MicMuteWidget(),
            PrivacyIndicatorWidget(),
            CallIslandWidget(),
            QuickNotesWidget(),
            BatteryWidget(),
            AirDropWidget(),
            CalendarWidget(),
            ClockWidget(),
            QuickActionsWidget(),
            TimerWidget(),
            ConnectivityWidget(),
            ClipboardWidget()
        ])

        // Setup Floating Dynamic Island Panel & Launch Entrance Animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            WindowManager.shared.setupPanel()

            // Always open Ivors Preferences window on launch for instant visual feedback!
            self.openPreferences()

            // Trigger Entrance Animation around Camera Notch on Application Startup!
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                EventBus.shared.post(.customNotification(
                    title: "Ivors Active",
                    message: "Dynamic Island ready",
                    icon: "sparkles",
                    type: .info
                ))
            }
        }

        // Create Status Item Menu Bar Icon
        setupStatusItem()
        setupSystemPowerObservers()
    }

    private func setupSystemPowerObservers() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { _ in
            EventBus.shared.post(.customNotification(
                title: "Display Sleeping",
                message: "Mac entering sleep mode",
                icon: "lock.fill",
                type: .warning
            ))
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { _ in
            EventBus.shared.post(.customNotification(
                title: "Welcome Back",
                message: "Dynamic Island ready",
                icon: "lock.open.fill",
                type: .success
            ))
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            let image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Ivors Dynamic Island")
            image?.isTemplate = true
            button.image = image
        }

        let menu = NSMenu()
        menu.autoenablesItems = false

        let toggleItem = NSMenuItem(title: "Toggle Expanded Island", action: #selector(toggleIsland), keyEquivalent: "i")
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        let prefsItem = NSMenuItem(title: "Ivors Preferences...", action: #selector(openPreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        menu.addItem(NSMenuItem.separator())

        let uninstallItem = NSMenuItem(title: "Uninstall Ivors...", action: #selector(confirmAndUninstall), keyEquivalent: "")
        uninstallItem.target = self
        menu.addItem(uninstallItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Ivors", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc private func toggleIsland() {
        WindowManager.shared.toggleIslandState()
    }

    @objc private func confirmAndUninstall() {
        let alert = NSAlert()
        alert.messageText = "Uninstall Ivors?"
        alert.informativeText = "This will quit Ivors and remove all application files and preferences from your Mac."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Uninstall & Quit")
        alert.addButton(withTitle: "Cancel")

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/bash")
            task.arguments = ["-c", "sleep 0.5; killall Ivors 2>/dev/null; brew uninstall --cask ivors 2>/dev/null; rm -rf /Applications/Ivors.app ~/Library/Preferences/com.mayank.ivors.plist ~/Library/Application\\ Support/Ivors"]
            try? task.run()
            NSApplication.shared.terminate(nil)
        }
    }

    @objc private func openPreferences() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 620, height: 440),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Ivors Preferences"
            window.contentView = NSHostingView(rootView: SettingsView())
            window.center()
            self.settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        WindowManager.shared.toggleIslandState()
        openPreferences()
        return true
    }
}
