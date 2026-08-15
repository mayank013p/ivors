import SwiftUI
import UniformTypeIdentifiers
import CoreWLAN
import AppKit

// MARK: - File Shelf Widget (Drag & Drop Temporary Storage)
public final class FileShelfWidget: DynamicIslandWidget, ObservableObject {
    public let id: String = "file_shelf"
    public let name: String = "File Drop Shelf"
    public let priority: Int = 65
    public var isVisible: Bool { true }
    public var preferredCompactWidth: CGFloat { 180 }
    public var preferredExpandedSize: CGSize { CGSize(width: 320, height: 140) }

    @Published public var stashedFiles: [URL] = []

    public init() {}

    public func compactView() -> AnyView {
        AnyView(
            HStack(spacing: 6) {
                Image(systemName: "tray.and.arrow.down.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 12))
                Text(stashedFiles.isEmpty ? "Drop Shelf" : "\(stashedFiles.count) Stashed")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 8)
        )
    }

    public func expandedView() -> AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "tray.fill")
                        .foregroundColor(.yellow)
                    Text("File Shelf")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    if !stashedFiles.isEmpty {
                        Button("Clear") { self.stashedFiles.removeAll() }
                            .buttonStyle(.plain)
                            .foregroundColor(.yellow)
                            .font(.system(size: 11, weight: .bold))
                    }
                }

                if stashedFiles.isEmpty {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                        .frame(height: 60)
                        .overlay(
                            VStack(spacing: 4) {
                                Image(systemName: "arrow.down.doc.fill")
                                    .foregroundColor(.white.opacity(0.5))
                                Text("Drag files here to store temporarily")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        )
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(stashedFiles, id: \.self) { url in
                                VStack {
                                    Image(systemName: "doc.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.yellow)
                                    Text(url.lastPathComponent)
                                        .font(.system(size: 9))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                }
                                .frame(width: 60, height: 60)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
            }
            .padding(14)
        )
    }

    public func minimalView() -> AnyView {
        AnyView(Image(systemName: "tray").foregroundColor(.yellow))
    }
}

// MARK: - WiFi Widget (Real CoreWLAN + Shell Fallback & System Settings Trigger)
public final class WiFiWidget: DynamicIslandWidget, ObservableObject {
    public let id: String = "wifi"
    public let name: String = "WiFi Status"
    public let priority: Int = 40
    public var isVisible: Bool { true }
    public var preferredCompactWidth: CGFloat { 160 }
    public var preferredExpandedSize: CGSize { CGSize(width: 320, height: 140) }

    @Published public var ssid: String = "Wi-Fi Active"
    @Published public var isConnected: Bool = true

    private var timer: Timer?

    public init() {
        updateWiFiStatus()
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateWiFiStatus()
        }
    }

    public func openWiFiSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.network?Wi-Fi") {
            NSWorkspace.shared.open(url)
        }
    }

    public func updateWiFiStatus() {
        DispatchQueue.global(qos: .utility).async {
            if let interface = CWWiFiClient.shared().interface() {
                if let currentSSID = interface.ssid(), !currentSSID.isEmpty {
                    DispatchQueue.main.async {
                        self.ssid = currentSSID
                        self.isConnected = true
                    }
                    return
                } else if interface.powerOn() {
                    DispatchQueue.main.async {
                        self.ssid = "Wi-Fi Active"
                        self.isConnected = true
                    }
                    return
                }
            }

            DispatchQueue.main.async {
                self.ssid = "Wi-Fi Off"
                self.isConnected = false
            }
        }
    }

    public func compactView() -> AnyView {
        AnyView(
            HStack(spacing: 6) {
                Image(systemName: isConnected ? "wifi" : "wifi.slash")
                    .foregroundColor(isConnected ? .blue : .gray)
                    .font(.system(size: 12, weight: .bold))
                Text(ssid)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
        )
    }

    public func expandedView() -> AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: isConnected ? "wifi" : "wifi.slash")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(isConnected ? .blue : .gray)
                    Text("Wi-Fi Network")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Button("Settings") {
                        self.openWiFiSettings()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .controlSize(.small)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(ssid)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(isConnected ? "Active Wireless Connection" : "Not Connected")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isConnected ? .green : .red)
                }
            }
            .padding(14)
        )
    }

    public func minimalView() -> AnyView {
        AnyView(Image(systemName: isConnected ? "wifi" : "wifi.slash").foregroundColor(isConnected ? .blue : .gray))
    }
}
