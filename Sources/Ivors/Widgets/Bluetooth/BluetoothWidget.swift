import SwiftUI
import AppKit

public final class BluetoothWidget: DynamicIslandWidget, ObservableObject {
    public let id: String = "bluetooth"
    public let name: String = "Bluetooth"
    public let priority: Int = 75
    public var isVisible: Bool { true }
    public var preferredCompactWidth: CGFloat { 170 }
    public var preferredExpandedSize: CGSize { CGSize(width: 320, height: 140) }

    @ObservedObject private var manager = BluetoothManager.shared

    public init() {}

    public func openBluetoothSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.bluetooth") {
            NSWorkspace.shared.open(url)
        }
    }

    public func compactView() -> AnyView {
        let first = manager.connectedDevices.first
        return AnyView(
            HStack(spacing: 6) {
                Image(systemName: first?.iconName ?? "wave.3.right")
                    .foregroundColor(.blue)
                    .font(.system(size: 13, weight: .bold))
                Text(first?.name ?? "Bluetooth Active")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                if let bat = first?.batteryPercentage {
                    Text("\(bat)%")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 8)
        )
    }

    public func expandedView() -> AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "wave.3.right")
                        .foregroundColor(.blue)
                        .font(.system(size: 16, weight: .bold))
                    Text("Bluetooth Devices")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Button("Settings") {
                        self.openBluetoothSettings()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .controlSize(.small)
                }

                ForEach(manager.connectedDevices.prefix(2), id: \.name) { dev in
                    HStack {
                        Image(systemName: dev.iconName)
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                        Text(dev.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Spacer()
                        if let bat = dev.batteryPercentage {
                            Text("\(bat)%")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.green)
                        } else {
                            Text(dev.isConnected ? "Connected" : "Not Connected")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(dev.isConnected ? .green : .gray)
                        }
                    }
                }
            }
            .padding(14)
        )
    }

    public func minimalView() -> AnyView {
        AnyView(
            Image(systemName: "wave.3.right")
                .foregroundColor(.blue)
                .font(.system(size: 12))
        )
    }
}
