import SwiftUI
import AppKit

public final class QuickActionsWidget: DynamicIslandWidget, ObservableObject {
    public let id: String = "quick_actions"
    public let name: String = "Quick Actions"
    public let priority: Int = 50 // Middle Priority
    public var isVisible: Bool { true }
    public var preferredCompactWidth: CGFloat { 180 }
    public var preferredExpandedSize: CGSize { CGSize(width: 350, height: 160) }

    @Published public var isMicMuted: Bool = false
    @Published public var isDarkMode: Bool = true

    public init() {}

    public func toggleMicMute() {
        isMicMuted.toggle()
        let val = isMicMuted ? 0 : 100
        let script = "set volume input volume \(val)"
        runAppleScript(script)
        EventBus.shared.post(.customNotification(
            title: isMicMuted ? "Microphone Muted" : "Microphone Active",
            message: isMicMuted ? "Audio input disabled" : "Audio input enabled",
            icon: isMicMuted ? "mic.slash.fill" : "mic.fill",
            type: isMicMuted ? .warning : .success
        ))
    }

    public func lockScreen() {
        EventBus.shared.post(.customNotification(
            title: "Locking Display",
            message: "Screen put to sleep",
            icon: "lock.fill",
            type: .warning
        ))
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        task.arguments = ["displaysleepnow"]
        try? task.run()
    }

    public func takeScreenshot() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = ["-i", "-c"] // Interactive area screenshot copied to pasteboard
        try? task.run()
        EventBus.shared.post(.customNotification(
            title: "Screenshot Tool Active",
            message: "Select screen area to copy to clipboard",
            icon: "viewfinder",
            type: .info
        ))
    }

    public func toggleDarkMode() {
        isDarkMode.toggle()
        let script = "tell application \"System Events\" to set dark mode of appearance preferences to not dark mode"
        runAppleScript(script)
    }

    private func runAppleScript(_ code: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            if let script = NSAppleScript(source: code) {
                var error: NSDictionary?
                script.executeAndReturnError(&error)
            }
        }
    }

    public func compactView() -> AnyView {
        AnyView(
            HStack(spacing: 8) {
                Image(systemName: "bolt.horizontal.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 12))
                Text("Quick Actions")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 8)
        )
    }

    public func expandedView() -> AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Grid(alignment: .center, horizontalSpacing: 8, verticalSpacing: 8) {
                    GridRow {
                        Button(action: { self.toggleMicMute() }) {
                            HStack(spacing: 6) {
                                Image(systemName: isMicMuted ? "mic.slash.fill" : "mic.fill")
                                    .foregroundColor(isMicMuted ? .red : .green)
                                Text(isMicMuted ? "Unmute Mic" : "Mute Mic")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .frame(maxWidth: .infinity, minHeight: 32)
                            .background(isMicMuted ? Color.red.opacity(0.2) : Color.white.opacity(0.08))
                            .cornerRadius(7)
                        }
                        .buttonStyle(.plain)

                        Button(action: { self.takeScreenshot() }) {
                            HStack(spacing: 6) {
                                Image(systemName: "viewfinder")
                                    .foregroundColor(.cyan)
                                Text("Screenshot")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .frame(maxWidth: .infinity, minHeight: 32)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(7)
                        }
                        .buttonStyle(.plain)
                    }

                    GridRow {
                        Button(action: { self.toggleDarkMode() }) {
                            HStack(spacing: 6) {
                                Image(systemName: "moon.stars.fill")
                                    .foregroundColor(.purple)
                                Text("Toggle Theme")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .frame(maxWidth: .infinity, minHeight: 32)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(7)
                        }
                        .buttonStyle(.plain)

                        Button(action: { self.lockScreen() }) {
                            HStack(spacing: 6) {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.orange)
                                Text("Lock Display")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .frame(maxWidth: .infinity, minHeight: 32)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(7)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 4)
        )
    }

    public func minimalView() -> AnyView {
        AnyView(Image(systemName: "bolt.horizontal.fill").foregroundColor(.yellow))
    }
}
