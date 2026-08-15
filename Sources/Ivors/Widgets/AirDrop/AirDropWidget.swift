import SwiftUI
import AppKit
import UniformTypeIdentifiers

public final class AirDropManager {
    public static let shared = AirDropManager()

    public func shareViaAirDrop(urls: [URL]) {
        guard !urls.isEmpty else { return }
        DispatchQueue.main.async {
            if let service = NSSharingService(named: .sendViaAirDrop) {
                if service.canPerform(withItems: urls) {
                    service.perform(withItems: urls)
                    let name = urls.count == 1 ? urls[0].lastPathComponent : "\(urls.count) Files"
                    EventBus.shared.post(.customNotification(
                        title: "AirDrop Sharing Active",
                        message: "Sending \(name) via AirDrop",
                        icon: "shareplay",
                        type: .info
                    ))
                }
            }
        }
    }

    public func shareClipboardViaAirDrop() {
        let pb = NSPasteboard.general
        if let str = pb.string(forType: .string), !str.isEmpty {
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent("Shared_Snippet.txt")
            try? str.write(to: fileURL, atomically: true, encoding: .utf8)
            shareViaAirDrop(urls: [fileURL])
        }
    }

    public func promptFileAndAirDrop() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "AirDrop"
        panel.begin { response in
            if response == .OK {
                self.shareViaAirDrop(urls: panel.urls)
            }
        }
    }

    public func openAirDropInFinder() {
        let airDropURL = URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app/Contents/Applications/AirDrop.app")
        if FileManager.default.fileExists(atPath: airDropURL.path) {
            NSWorkspace.shared.open(airDropURL)
        } else {
            if let finderURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.finder") {
                NSWorkspace.shared.openApplication(at: finderURL, configuration: NSWorkspace.OpenConfiguration())
            }
        }
    }
}

public final class AirDropWidget: DynamicIslandWidget, ObservableObject {
    public let id: String = "airdrop"
    public let name: String = "AirDrop"
    public let priority: Int = 68
    public var isVisible: Bool { true }
    public var preferredCompactWidth: CGFloat { 180 }
    public var preferredExpandedSize: CGSize { CGSize(width: 350, height: 160) }

    @Published public var isTargeted: Bool = false

    public init() {}

    public func compactView() -> AnyView {
        AnyView(
            HStack(spacing: 6) {
                Image(systemName: "shareplay")
                    .foregroundColor(.blue)
                    .font(.system(size: 12, weight: .bold))
                Text("AirDrop")
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
                    Image(systemName: "shareplay")
                        .foregroundColor(.blue)
                        .font(.system(size: 16, weight: .bold))
                    Text("AirDrop Sharing")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Button("Open Finder") {
                        AirDropManager.shared.openAirDropInFinder()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .controlSize(.small)
                }

                // Interactive File Drop Target Zone
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isTargeted ? Color.blue : Color.white.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                    .background(isTargeted ? Color.blue.opacity(0.15) : Color.white.opacity(0.04))
                    .cornerRadius(10)
                    .frame(height: 52)
                    .overlay(
                        VStack(spacing: 3) {
                            Image(systemName: isTargeted ? "arrow.down.circle.fill" : "shareplay")
                                .foregroundColor(isTargeted ? .blue : .white.opacity(0.7))
                                .font(.system(size: 16))
                            Text(isTargeted ? "Drop files to AirDrop instantly" : "Drag files here to AirDrop")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    )

                HStack(spacing: 10) {
                    Button(action: { AirDropManager.shared.promptFileAndAirDrop() }) {
                        HStack(spacing: 5) {
                            Image(systemName: "doc.badge.plus")
                            Text("Pick File")
                        }
                        .font(.system(size: 11, weight: .bold))
                        .frame(maxWidth: .infinity, minHeight: 28)
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)

                    Button(action: { AirDropManager.shared.shareClipboardViaAirDrop() }) {
                        HStack(spacing: 5) {
                            Image(systemName: "doc.on.clipboard")
                            Text("AirDrop Clipboard")
                        }
                        .font(.system(size: 11, weight: .bold))
                        .frame(maxWidth: .infinity, minHeight: 28)
                    }
                    .buttonStyle(.bordered)
                    .tint(.cyan)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 4)
        )
    }

    public func minimalView() -> AnyView {
        AnyView(Image(systemName: "shareplay").foregroundColor(.blue))
    }
}
