import Foundation
import SwiftUI
import Combine
import AppKit

// MARK: - 1. AI Usage Tracker Widget
public final class AIUsageWidget: DynamicIslandWidget, ObservableObject {
    public let id: String = "ai_usage"
    public let title: String = "AI Usage Tracker"
    public let iconName: String = "cpu"
    public var priority: Int = 85

    @Published public var claudeTokensUsed: Int = 84000
    @Published public var claudeTokenLimit: Int = 100000
    @Published public var estimatedCost: Double = 0.14
    @Published public var activeModel: String = "Claude 3.7 Sonnet"

    public init() {}

    public func compactView() -> AnyView {
        AnyView(
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.purple)
                Text("\(activeModel): \(Int(Double(claudeTokensUsed)/Double(claudeTokenLimit)*100))%")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
            }
        )
    }

    public func expandedView() -> AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "cpu.fill")
                        .foregroundColor(.purple)
                    Text("AI Rate-Limit & Token Usage")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Text("Cost: $\(String(format: "%.2f", estimatedCost))")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.green)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(activeModel)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                        Spacer()
                        Text("\(claudeTokensUsed) / \(claudeTokenLimit) tokens")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.15))
                            Capsule().fill(Color.purple)
                                .frame(width: geo.size.width * CGFloat(self.claudeTokensUsed) / CGFloat(self.claudeTokenLimit))
                        }
                    }
                    .frame(height: 6)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.4)))
        )
    }
}

// MARK: - 2. Zoom Teleprompter (Cuely) Widget
public final class ZoomTeleprompterWidget: DynamicIslandWidget, ObservableObject {
    public let id: String = "teleprompter"
    public let title: String = "Cuely Teleprompter"
    public let iconName: String = "video.fill"
    public var priority: Int = 80

    @Published public var scriptText: String = "Welcome investors to our Q3 demo. Ivors brings 71 native features directly to your Mac camera notch..."
    @Published public var isScrolling: Bool = false
    @Published public var scrollSpeed: Double = 1.5

    public init() {}

    public func compactView() -> AnyView {
        AnyView(
            HStack(spacing: 5) {
                Image(systemName: "video.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.red)
                Text("Cuely Script Active")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
            }
        )
    }

    public func expandedView() -> AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "text.alignleft")
                        .foregroundColor(.cyan)
                    Text("Cuely Camera Teleprompter")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: { [weak self] in self?.isScrolling.toggle() }) {
                        Text(self.isScrolling ? "Pause" : "Start Scroll")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(self.isScrolling ? Color.red : Color.cyan)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
                Text(scriptText)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(3)
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.4)))
        )
    }
}

// MARK: - 3. Synced Lyrics (LRCLIB) Widget
public final class SyncedLyricsWidget: DynamicIslandWidget, ObservableObject {
    public let id: String = "lyrics"
    public let title: String = "Synced Lyrics"
    public let iconName: String = "quote.bubble.fill"
    public var priority: Int = 78

    @Published public var currentLyricLine: String = "Yeah, I'm gonna take my horse to the old town road..."
    @Published public var songTitle: String = "Midnight City — M83"

    public init() {}

    public func compactView() -> AnyView {
        AnyView(
            HStack(spacing: 4) {
                Image(systemName: "quote.bubble.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
                Text(currentLyricLine)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
        )
    }

    public func expandedView() -> AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "music.mic")
                        .foregroundColor(.orange)
                    Text("Time-Synced Lyrics (LRCLIB)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
                Text(currentLyricLine)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.4)))
        )
    }
}

// MARK: - 4. Notch Terminal (VT100) Widget
public final class NotchTerminalWidget: DynamicIslandWidget, ObservableObject {
    public let id: String = "terminal"
    public let title: String = "Notch VT100 Terminal"
    public let iconName: String = "terminal.fill"
    public var priority: Int = 82

    @Published public var lastCommandOutput: String = "$ sw_vers\nProductName: macOS\nProductVersion: 14.4\nBuildVersion: 23E214"
    @Published public var currentInput: String = ""

    public init() {
        runRealCommand("sw_vers")
    }

    public func runRealCommand(_ command: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            let pipe = Pipe()
            task.executableURL = URL(fileURLWithPath: "/bin/zsh")
            task.arguments = ["-c", command]
            task.standardOutput = pipe
            task.standardError = pipe
            do {
                try task.run()
                task.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                    DispatchQueue.main.async {
                        self.lastCommandOutput = "$ \(command)\n" + output.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.lastCommandOutput = "$ \(command)\nError executing command: \(error.localizedDescription)"
                }
            }
        }
    }

    public func compactView() -> AnyView {
        AnyView(
            HStack(spacing: 4) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.green)
                Text("VT100 PTY Active")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
            }
        )
    }

    public func expandedView() -> AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "terminal.fill")
                        .foregroundColor(.green)
                    Text("Notch VT100 Shell")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                }

                ScrollView {
                    Text(lastCommandOutput)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.green)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .background(Color.black)
                .cornerRadius(8)

                HStack(spacing: 6) {
                    Button(action: { self.runRealCommand("git status") }) {
                        Text("git status").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.white).padding(.horizontal, 8).padding(.vertical, 4).background(Color.white.opacity(0.15)).cornerRadius(6)
                    }.buttonStyle(.plain)

                    Button(action: { self.runRealCommand("sw_vers") }) {
                        Text("sw_vers").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.white).padding(.horizontal, 8).padding(.vertical, 4).background(Color.white.opacity(0.15)).cornerRadius(6)
                    }.buttonStyle(.plain)

                    Button(action: { self.runRealCommand("df -h") }) {
                        Text("df -h").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.white).padding(.horizontal, 8).padding(.vertical, 4).background(Color.white.opacity(0.15)).cornerRadius(6)
                    }.buttonStyle(.plain)

                    Button(action: { self.runRealCommand("uptime") }) {
                        Text("uptime").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.white).padding(.horizontal, 8).padding(.vertical, 4).background(Color.white.opacity(0.15)).cornerRadius(6)
                    }.buttonStyle(.plain)
                }
            }
            .padding(10)
        )
    }
}

// MARK: - 5. System Stats (iStat) Widget
public final class SystemStatsWidget: DynamicIslandWidget, ObservableObject {
    public let id: String = "system_stats"
    public let title: String = "System Stats"
    public let iconName: String = "gauge"
    public var priority: Int = 75

    @Published public var cpuUsage: Int = 12
    @Published public var ramUsage: Int = 48
    @Published public var networkSpeed: String = "↓ 4.2 MB/s"

    public init() {}

    public func compactView() -> AnyView {
        AnyView(
            HStack(spacing: 8) {
                Text("CPU \(cpuUsage)%")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
                Text("RAM \(ramUsage)%")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.yellow)
            }
        )
    }

    public func expandedView() -> AnyView {
        AnyView(
            HStack(spacing: 12) {
                VStack {
                    Text("CPU")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                    Text("\(cpuUsage)%")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                }
                Spacer()
                VStack {
                    Text("RAM")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                    Text("\(ramUsage)%")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.yellow)
                }
                Spacer()
                VStack {
                    Text("NET")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                    Text(networkSpeed)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.4)))
        )
    }
}

// MARK: - 6. Command Palette (⌃⌥K) Widget
public final class CommandPaletteWidget: DynamicIslandWidget, ObservableObject {
    public let id: String = "command_palette"
    public let title: String = "Command Palette (⌃⌥K)"
    public let iconName: String = "command"
    public var priority: Int = 90

    @Published public var searchQuery: String = ""

    public init() {}

    public func compactView() -> AnyView {
        AnyView(
            HStack(spacing: 4) {
                Image(systemName: "command")
                    .font(.system(size: 10))
                    .foregroundColor(.cyan)
                Text("Press ⌃⌥K")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
        )
    }

    public func expandedView() -> AnyView {
        AnyView(
            VStack(spacing: 6) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.cyan)
                    Text("Command Palette")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Text("⌘1–9 Tabs")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                }
                HStack {
                    Image(systemName: "terminal")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                    Text("Type command or action (e.g. Caffeine, Timer)...")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                    Spacer()
                }
                .padding(6)
                .background(Color.black.opacity(0.6))
                .cornerRadius(6)
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.4)))
        )
    }
}

// MARK: - 7. Quick Notes Widget
public final class QuickNotesWidget: DynamicIslandWidget, ObservableObject {
    public let id: String = "quick_notes"
    public let title: String = "Quick Notes"
    public let iconName: String = "note.text"
    public var priority: Int = 70

    @Published public var noteText: String = "Drafting new product release notes..."

    public init() {}

    public func compactView() -> AnyView {
        AnyView(
            HStack(spacing: 4) {
                Image(systemName: "note.text")
                    .font(.system(size: 10))
                    .foregroundColor(.yellow)
                Text("Note Staged")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
        )
    }

    public func expandedView() -> AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "square.and.pencil")
                        .foregroundColor(.yellow)
                    Text("Notch Quick Note")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
                Text(noteText)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(6)
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.4)))
        )
    }
}

// MARK: - 8. Mic Mute Widget
public final class MicMuteWidget: DynamicIslandWidget, ObservableObject {
    public let id: String = "mic_mute"
    public let title: String = "System Mic Mute"
    public let iconName: String = "mic.slash.fill"
    public var priority: Int = 88

    @Published public var isMuted: Bool = true

    public init() {}

    public func compactView() -> AnyView {
        AnyView(
            HStack(spacing: 4) {
                Image(systemName: isMuted ? "mic.slash.fill" : "mic.fill")
                    .font(.system(size: 10))
                    .foregroundColor(isMuted ? .red : .green)
                Text(isMuted ? "Mic Muted" : "Mic Live")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
        )
    }

    public func expandedView() -> AnyView {
        AnyView(
            HStack {
                Image(systemName: isMuted ? "mic.slash.fill" : "mic.fill")
                    .font(.system(size: 16))
                    .foregroundColor(isMuted ? .red : .green)
                VStack(alignment: .leading) {
                    Text(isMuted ? "CoreAudio Input Muted" : "CoreAudio Input Active")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                    Text("Silences Zoom, Teams & Meet system-wide")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                Button(action: { [weak self] in self?.isMuted.toggle() }) {
                    Text(isMuted ? "Unmute" : "Mute")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(isMuted ? Color.green : Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.4)))
        )
    }
}

// MARK: - 9. Privacy Indicator Widget
public final class PrivacyIndicatorWidget: DynamicIslandWidget, ObservableObject {
    public let id: String = "privacy_indicator"
    public let title: String = "Privacy Dot Indicator"
    public let iconName: String = "eye.fill"
    public var priority: Int = 95

    @Published public var cameraActive: Bool = false
    @Published public var micActive: Bool = false

    public init() {}

    public func compactView() -> AnyView {
        AnyView(
            HStack(spacing: 4) {
                Circle().fill(Color.green).frame(width: 6, height: 6)
                Circle().fill(Color.orange).frame(width: 6, height: 6)
                Text("Privacy Monitor")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
            }
        )
    }

    public func expandedView() -> AnyView {
        AnyView(
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Circle().fill(cameraActive ? Color.green : Color.gray).frame(width: 8, height: 8)
                    Text("Camera Feed: \(cameraActive ? "Active" : "Idle")")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                }
                HStack(spacing: 6) {
                    Circle().fill(micActive ? Color.orange : Color.gray).frame(width: 8, height: 8)
                    Text("Mic Input: \(micActive ? "Active" : "Idle")")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.4)))
        )
    }
}

// MARK: - 10. Call Island Widget
public final class CallIslandWidget: DynamicIslandWidget, ObservableObject {
    public let id: String = "call_island"
    public let title: String = "Call Island"
    public let iconName: String = "phone.fill"
    public var priority: Int = 92

    @Published public var callerName: String = "Incoming FaceTime: Alex Rivera"

    public init() {}

    public func compactView() -> AnyView {
        AnyView(
            HStack(spacing: 5) {
                Image(systemName: "phone.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.green)
                Text("FaceTime Call")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
        )
    }

    public func expandedView() -> AnyView {
        AnyView(
            HStack {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.green)
                VStack(alignment: .leading) {
                    Text(callerName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                    Text("iPhone Call Relay")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                HStack(spacing: 6) {
                    Button("Decline") {}
                        .buttonStyle(.plain)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    Button("Answer") {}
                        .buttonStyle(.plain)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.4)))
        )
    }
}

