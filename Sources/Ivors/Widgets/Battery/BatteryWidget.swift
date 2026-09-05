import SwiftUI
import Combine
import AppKit

public struct SystemNotificationItem: Identifiable {
    public let id = UUID()
    public let title: String
    public let message: String
    public let icon: String
    public let artwork: NSImage?
    public let type: NotificationType
    public let timestamp: Date
}

public final class BatteryWidget: DynamicIslandWidget, ObservableObject {
    public let id: String = "battery"
    public let name: String = "Battery & HUD"
    public var priority: Int { isShowingPopup ? 150 : 90 }
    public var isVisible: Bool { true }
    public var preferredCompactWidth: CGFloat { 210 }
    public var preferredExpandedSize: CGSize { CGSize(width: 350, height: 160) }

    @ObservedObject private var batteryManager = BatteryManager.shared
    @Published public var currentNotification: SystemNotificationItem?
    @Published public var isShowingPopup: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private var timer: Timer?
    private var isInitialCheck: Bool = true
    private var previousChargingState: Bool? = nil
    private var previousBatteryLevel: Int = 100
    private var previousWiFiState: Bool? = nil

    public init() {
        self.previousChargingState = BatteryManager.shared.isCharging
        self.previousBatteryLevel = BatteryManager.shared.batteryLevel
        self.isInitialCheck = false
        setupEventBusObserver()
    }

    public func showNotification(title: String, message: String, icon: String, type: NotificationType = .info, artwork: NSImage? = nil) {
        let item = SystemNotificationItem(
            title: title,
            message: message,
            icon: icon,
            artwork: artwork,
            type: type,
            timestamp: Date()
        )
        DispatchQueue.main.async {
            self.currentNotification = item
            self.isShowingPopup = true
            WidgetManager.shared.triggerTemporaryPopup(widgetId: "battery", duration: 3.0)

            self.timer?.invalidate()
            self.timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                withAnimation(AnimationController.defaultSpring) {
                    self?.isShowingPopup = false
                    self?.currentNotification = nil
                }
            }
        }
    }

    private func setupEventBusObserver() {
        EventBus.shared.publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                switch event {
                case .customNotification(let title, let message, let icon, let type, let artwork):
                    self.showNotification(title: title, message: message, icon: icon, type: type, artwork: artwork)

                case .trackChanged(let title, let artist, let artwork):
                    self.showNotification(
                        title: "Now Playing",
                        message: "\(title) • \(artist)",
                        icon: "music.note",
                        type: .info,
                        artwork: artwork
                    )

                case .trackArtworkUpdated(let artwork):
                    if self.isShowingPopup, let current = self.currentNotification, current.title == "Now Playing" {
                        self.currentNotification = SystemNotificationItem(
                            title: current.title,
                            message: current.message,
                            icon: current.icon,
                            artwork: artwork,
                            type: current.type,
                            timestamp: current.timestamp
                        )
                    }

                case .clipboardUpdated(let text):
                    let snippet = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    let displaySnippet = snippet.count > 32 ? String(snippet.prefix(32)) + "..." : snippet
                    self.showNotification(
                        title: "Copied to Clipboard",
                        message: displaySnippet.isEmpty ? "Content copied" : displaySnippet,
                        icon: "doc.on.clipboard.fill",
                        type: .info
                    )

                case .batteryStateChanged(let level, let isCharging):
                    if self.isInitialCheck {
                        self.isInitialCheck = false
                        self.previousChargingState = isCharging
                        self.previousBatteryLevel = level
                        return
                    }

                    if isCharging && self.previousChargingState == false {
                        self.showNotification(
                            title: "Power Adapter Connected",
                            message: "Charging at \(level)%",
                            icon: "bolt.fill",
                            type: .success
                        )
                    } else if !isCharging && self.previousChargingState == true {
                        self.showNotification(
                            title: "Power Adapter Disconnected",
                            message: "On Battery Power (\(level)%)",
                            icon: "battery.75",
                            type: .warning
                        )
                    } else if level <= 20 && !isCharging && self.previousBatteryLevel > 20 {
                        self.showNotification(
                            title: "Low Battery Warning",
                            message: "\(level)% Battery Remaining",
                            icon: "exclamationmark.triangle.fill",
                            type: .error
                        )
                    }
                    self.previousChargingState = isCharging
                    self.previousBatteryLevel = level

                case .bluetoothDeviceConnected(let name):
                    let iconName = name.lowercased().contains("airpod") ? "airpodspro" : "wave.3.right"
                    self.showNotification(
                        title: "Bluetooth Connected",
                        message: name,
                        icon: iconName,
                        type: .info
                    )

                case .bluetoothDeviceDisconnected(let name):
                    self.showNotification(
                        title: "Bluetooth Disconnected",
                        message: name,
                        icon: "wave.3.right",
                        type: .warning
                    )

                case .wifiStatusChanged(let connected, let ssid):
                    if let prev = self.previousWiFiState, prev != connected {
                        if connected {
                            self.showNotification(
                                title: "Wi-Fi Connected",
                                message: ssid,
                                icon: "wifi",
                                type: .info
                            )
                        } else {
                            self.showNotification(
                                title: "Wi-Fi Disconnected",
                                message: "No Network Connection",
                                icon: "wifi.slash",
                                type: .warning
                            )
                        }
                    }
                    self.previousWiFiState = connected

                case .focusModeChanged(let enabled, let name):
                    self.showNotification(
                        title: enabled ? "Focus Mode Active" : "Focus Mode Off",
                        message: name,
                        icon: enabled ? "moon.fill" : "sun.max.fill",
                        type: .info
                    )

                default:
                    break
                }
            }
            .store(in: &cancellables)
    }

    public func compactView() -> AnyView {
        if isShowingPopup, let note = currentNotification {
            return AnyView(
                HStack(spacing: 6) {
                    if let art = note.artwork {
                        Image(nsImage: art)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 22, height: 22)
                            .cornerRadius(5)
                    } else {
                        AnimatedBadgeIcon(icon: note.icon, color: colorForType(note.type))
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        Text(note.title)
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(note.message)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 6)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            )
        }

        return AnyView(
            HStack(spacing: 6) {
                Image(systemName: batteryManager.isCharging ? "bolt.batteryblock.fill" : "battery.100")
                    .foregroundColor(batteryManager.batteryLevel <= 20 ? .red : (batteryManager.isCharging ? .green : .white))
                    .font(.system(size: 13, weight: .bold))

                Text("\(batteryManager.batteryLevel)%")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 6)
        )
    }

    public func expandedView() -> AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: 10) {
                if let note = currentNotification, isShowingPopup {
                    HStack(spacing: 8) {
                        if let art = note.artwork {
                            Image(nsImage: art)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 26, height: 26)
                                .cornerRadius(6)
                        } else {
                            AnimatedBadgeIcon(icon: note.icon, color: colorForType(note.type))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(note.title)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                            Text(note.message)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        Spacer()
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(8)
                }

                HStack {
                    ZStack {
                        Circle()
                            .fill(batteryManager.isCharging ? Color.green.opacity(0.2) : Color.white.opacity(0.1))
                            .frame(width: 38, height: 38)

                        Image(systemName: batteryManager.isCharging ? "bolt.fill" : "battery.100")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(batteryManager.isCharging ? .green : .white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(batteryManager.isCharging ? "Charging Active" : "On Battery Power")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        Text("\(batteryManager.batteryLevel)% Capacity Remaining")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }

                    Spacer()

                    Text("\(batteryManager.batteryLevel)%")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundColor(batteryManager.batteryLevel <= 20 ? .red : .white)
                }

                // Battery Progress Gauge
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                            .frame(height: 8)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: self.batteryManager.batteryLevel <= 20 ? [.red, .orange] : [.green, .mint],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * CGFloat(self.batteryManager.batteryLevel) / 100.0, height: 8)
                    }
                }
                .frame(height: 8)
            }
            .padding(.horizontal, 14)
            .padding(.top, 2)
        )
    }

    public func minimalView() -> AnyView {
        AnyView(
            HStack(spacing: 4) {
                Image(systemName: batteryManager.isCharging ? "bolt.fill" : "battery.100")
                    .foregroundColor(batteryManager.isCharging ? .green : .white)
                    .font(.system(size: 11))
                Text("\(batteryManager.batteryLevel)%")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
        )
    }

    private func colorForType(_ type: NotificationType) -> Color {
        switch type {
        case .info: return .cyan
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }
}

// MARK: - Animated Event Badge Icon with Glowing Pulse Ring
struct AnimatedBadgeIcon: View {
    let icon: String
    let color: Color
    @State private var isPulsing: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: 22, height: 22)

            Circle()
                .stroke(color.opacity(0.6), lineWidth: 1.5)
                .frame(width: 22, height: 22)
                .scaleEffect(isPulsing ? 1.35 : 1.0)
                .opacity(isPulsing ? 0.0 : 0.8)

            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 11, weight: .bold))
        }
        .frame(width: 22, height: 22)
        .onAppear {
            withAnimation(Animation.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                isPulsing = true
            }
        }
    }
}
