import SwiftUI
import AppKit

public final class ConnectivityWidget: DynamicIslandWidget, ObservableObject {
    public let id: String = "connectivity"
    public let name: String = "Connectivity"
    public let priority: Int = 75
    public var isVisible: Bool { true }
    public var preferredCompactWidth: CGFloat { 220 }
    public var preferredExpandedSize: CGSize { CGSize(width: 350, height: 160) }

    @ObservedObject private var wiFiWidget = WiFiWidget()
    @ObservedObject private var bluetoothManager = BluetoothManager.shared

    public init() {}

    public func openWiFiSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.network?Wi-Fi") {
            NSWorkspace.shared.open(url)
        }
    }

    public func openBluetoothSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.bluetooth") {
            NSWorkspace.shared.open(url)
        }
    }

    public func compactView() -> AnyView {
        let btDevice = bluetoothManager.connectedDevices.first
        return AnyView(
            HStack(spacing: 8) {
                // Wi-Fi Status
                HStack(spacing: 4) {
                    Image(systemName: wiFiWidget.isConnected ? "wifi" : "wifi.slash")
                        .foregroundColor(wiFiWidget.isConnected ? .blue : .gray)
                        .font(.system(size: 11, weight: .bold))
                    Text(wiFiWidget.ssid)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }

                Divider()
                    .frame(height: 12)
                    .background(Color.white.opacity(0.3))

                // Bluetooth Status
                HStack(spacing: 4) {
                    Image(systemName: btDevice?.iconName ?? "wave.3.right")
                        .foregroundColor(.cyan)
                        .font(.system(size: 11, weight: .bold))
                    Text(btDevice?.name ?? "Bluetooth")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 6)
        )
    }

    public func expandedView() -> AnyView {
        let btDevices = bluetoothManager.connectedDevices
        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                // 1. Wi-Fi Section
                HStack {
                    Image(systemName: wiFiWidget.isConnected ? "wifi" : "wifi.slash")
                        .foregroundColor(.blue)
                        .font(.system(size: 14, weight: .bold))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(wiFiWidget.ssid)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(wiFiWidget.isConnected ? "Wi-Fi Connected" : "Disconnected")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundColor(wiFiWidget.isConnected ? .green : .red)
                    }

                    Spacer()

                    Button("Wi-Fi Settings") {
                        self.openWiFiSettings()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .controlSize(.small)
                }
                .padding(8)
                .background(Color.white.opacity(0.06))
                .cornerRadius(8)

                // 2. Bluetooth Section
                HStack {
                    Image(systemName: "wave.3.right")
                        .foregroundColor(.cyan)
                        .font(.system(size: 14, weight: .bold))
                    VStack(alignment: .leading, spacing: 1) {
                        if let first = btDevices.first {
                            Text(first.name)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Text(first.isConnected ? "Bluetooth Device Connected" : "No Devices Connected")
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundColor(first.isConnected ? .cyan : .gray)
                        } else {
                            Text("Bluetooth Active")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }

                    Spacer()

                    Button("Bluetooth") {
                        self.openBluetoothSettings()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)
                    .controlSize(.small)
                }
                .padding(8)
                .background(Color.white.opacity(0.06))
                .cornerRadius(8)
            }
            .padding(.horizontal, 14)
            .padding(.top, 2)
        )
    }

    public func minimalView() -> AnyView {
        AnyView(
            HStack(spacing: 2) {
                Image(systemName: "wifi")
                    .foregroundColor(.blue)
                    .font(.system(size: 10))
                Image(systemName: "wave.3.right")
                    .foregroundColor(.cyan)
                    .font(.system(size: 10))
            }
        )
    }
}
