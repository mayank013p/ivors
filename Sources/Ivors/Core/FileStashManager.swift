import Foundation
import AppKit
import UniformTypeIdentifiers

public struct StashedFile: Identifiable {
    public let id = UUID()
    public let url: URL
    public let name: String
    public let fileSizeString: String
    public let dateAdded: Date

    public init(url: URL) {
        self.url = url
        self.name = url.lastPathComponent
        self.dateAdded = Date()

        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int64 {
            self.fileSizeString = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        } else {
            self.fileSizeString = "Unknown"
        }
    }
}

public final class FileStashManager: ObservableObject {
    public static let shared = FileStashManager()

    @Published public var stashedFiles: [StashedFile] = []
    @Published public var statusMessage: String = "Ready for drag-and-drop file stash"

    private init() {
        // Shelf initializes cleanly
    }

    public func addFile(url: URL) {
        DispatchQueue.main.async {
            if !self.stashedFiles.contains(where: { $0.url == url }) {
                self.stashedFiles.insert(StashedFile(url: url), at: 0)
                self.statusMessage = "Added \(url.lastPathComponent) to shelf"
                EventBus.shared.post(.customNotification(
                    title: "File Stashed 📦",
                    message: url.lastPathComponent,
                    icon: "cube.fill",
                    type: .info
                ))
            }
        }
    }

    public func addFiles(_ urls: [URL]) {
        for url in urls {
            addFile(url: url)
        }
    }

    public func removeFile(_ item: StashedFile) {
        DispatchQueue.main.async {
            self.stashedFiles.removeAll(where: { $0.id == item.id })
        }
    }

    public func convertHeicToPng() {
        guard let first = stashedFiles.first(where: { $0.name.lowercased().hasSuffix(".heic") || $0.name.lowercased().hasSuffix(".png") || $0.name.lowercased().hasSuffix(".jpg") }) else {
            DispatchQueue.main.async {
                self.statusMessage = "No HEIC/JPG image selected to convert"
            }
            return
        }

        let inputPath = first.url.path
        let outputPath = (inputPath as NSString).deletingPathExtension + "_converted.png"

        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
            task.arguments = ["-s", "format", "png", inputPath, "--out", outputPath]
            do {
                try task.run()
                task.waitUntilExit()
                let outputURL = URL(fileURLWithPath: outputPath)
                DispatchQueue.main.async {
                    self.addFile(url: outputURL)
                    self.statusMessage = "Converted image to PNG!"
                }
            } catch {
                DispatchQueue.main.async {
                    self.statusMessage = "Conversion failed: \(error.localizedDescription)"
                }
            }
        }
    }

    public func createZipArchive() {
        guard !stashedFiles.isEmpty else {
            DispatchQueue.main.async { self.statusMessage = "No files in shelf to zip" }
            return
        }

        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let zipURL = downloadsURL.appendingPathComponent("Stashed_Files.zip")
        let zipPath = zipURL.path
        let filePaths = stashedFiles.map { $0.url.path }

        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
            var args = ["-j", zipPath]
            args.append(contentsOf: filePaths)
            task.arguments = args
            do {
                try task.run()
                task.waitUntilExit()
                let outputURL = URL(fileURLWithPath: zipPath)
                DispatchQueue.main.async {
                    self.addFile(url: outputURL)
                    self.statusMessage = "ZIP Archive Created!"
                }
            } catch {
                DispatchQueue.main.async {
                    self.statusMessage = "ZIP failed: \(error.localizedDescription)"
                }
            }
        }
    }

    public func shareAirDrop(_ item: StashedFile) {
        triggerAirDropForURLs([item.url])
    }

    public func triggerAirDropForURLs(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        DispatchQueue.main.async {
            if let service = NSSharingService(named: .sendViaAirDrop) {
                if service.canPerform(withItems: urls) {
                    service.perform(withItems: urls)
                    EventBus.shared.post(.customNotification(
                        title: "AirDrop Sharing 📡",
                        message: "Sharing \(urls.first?.lastPathComponent ?? "file") via AirDrop",
                        icon: "square.and.arrow.up.fill",
                        type: .info
                    ))
                    return
                }
            }
            let picker = NSSharingServicePicker(items: urls)
            if let window = NSApp.windows.first(where: { $0.isVisible }) {
                picker.show(relativeTo: .zero, of: window.contentView!, preferredEdge: .minY)
            }
        }
    }

    public func revealInFinder(_ item: StashedFile) {
        NSWorkspace.shared.selectFile(item.url.path, inFileViewerRootedAtPath: "")
    }
}
