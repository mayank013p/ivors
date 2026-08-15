import Foundation
import SwiftUI
import Combine
import ServiceManagement

public final class SettingsManager: ObservableObject {
    public static let shared = SettingsManager()

    @AppStorage("launchAtLogin") public var launchAtLogin: Bool = false {
        didSet {
            updateLaunchAtLogin(launchAtLogin)
        }
    }
    @AppStorage("accentColorName") public var accentColorName: String = "Orange"
    @AppStorage("islandScale") public var islandScale: Double = 1.0
    @AppStorage("animationSpeed") public var animationSpeed: Double = 1.0
    @AppStorage("blurIntensity") public var blurIntensity: Double = 1.0
    @AppStorage("autoHideDelay") public var autoHideDelay: Double = 1.2
    @AppStorage("enableHoverExpand") public var enableHoverExpand: Bool = true
    @AppStorage("enableClickToggle") public var enableClickToggle: Bool = true
    @AppStorage("showNotchIntegration") public var showNotchIntegration: Bool = true {
        didSet {
            IslandLayoutEngine.shared.updateNotchGeometry()
            WindowManager.shared.updateFrame(for: WidgetManager.shared.activeState)
        }
    }
    @AppStorage("duoWidgetMode") public var duoWidgetMode: Bool = true
    @AppStorage("razorpayPaymentPageURL") public var razorpayPaymentPageURL: String = "https://ivors.app/checkout"



    @Published public var alwaysShowCompactBar: Bool = UserDefaults.standard.bool(forKey: "alwaysShowCompactBar") {
        didSet {
            UserDefaults.standard.set(alwaysShowCompactBar, forKey: "alwaysShowCompactBar")
        }
    }

    // Enabled widgets toggle map stored in UserDefaults
    @AppStorage("enabledWidgetsJSON") private var enabledWidgetsJSON: String = "{}"
    
    @Published public var enabledWidgets: [String: Bool] = [:]

    private init() {
        loadWidgetPreferences()
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        // Only run SMAppService when running from compiled .app bundle
        guard Bundle.main.bundlePath.hasSuffix(".app") else {
            return
        }

        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // Ignore silent registration notices
            }
        }
    }

    public var accentColor: Color {
        switch accentColorName {
        case "Blue": return .blue
        case "Purple": return .purple
        case "Pink": return .pink
        case "Green": return .green
        case "Red": return .red
        case "Yellow": return .yellow
        case "White": return .white
        default: return .orange
        }
    }

    private func loadWidgetPreferences() {
        if let data = enabledWidgetsJSON.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String: Bool].self, from: data) {
            self.enabledWidgets = decoded
        }
    }

    public func isWidgetEnabled(_ widgetId: String) -> Bool {
        return enabledWidgets[widgetId] ?? true
    }

    public func setWidgetEnabled(_ widgetId: String, enabled: Bool) {
        enabledWidgets[widgetId] = enabled
        if let data = try? JSONEncoder().encode(enabledWidgets),
           let jsonString = String(data: data, encoding: .utf8) {
            enabledWidgetsJSON = jsonString
        }
    }
}
