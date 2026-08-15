import SwiftUI
import AppKit
import Combine

public struct ClipboardItem: Identifiable {
    public let id = UUID()
    public let content: String
    public let timestamp: Date
}

public final class ClipboardWidget: DynamicIslandWidget, ObservableObject {
    public let id: String = "clipboard"
    public let name: String = "Clipboard History"
    public let priority: Int = 70
    public var isVisible: Bool { true }
    public var preferredCompactWidth: CGFloat { 190 }
    public var preferredExpandedSize: CGSize { CGSize(width: 340, height: 160) }

    @Published public var history: [ClipboardItem] = [
        ClipboardItem(content: "https://apple.com/macbook-pro", timestamp: Date()),
        ClipboardItem(content: "swift build -c release", timestamp: Date().addingTimeInterval(-120))
    ]
    @Published public var latestSnippet: String = "swift build -c release"

    private var changeCount: Int = 0
    private var timer: Timer?

    public init() {
        changeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }

    private func checkClipboard() {
        let pb = NSPasteboard.general
        if pb.changeCount != changeCount {
            changeCount = pb.changeCount
            if let str = pb.string(forType: .string), !str.isEmpty {
                DispatchQueue.main.async {
                    self.latestSnippet = str
                    if !self.history.contains(where: { $0.content == str }) {
                        self.history.insert(ClipboardItem(content: str, timestamp: Date()), at: 0)
                        if self.history.count > 10 { self.history.removeLast() }
                    }
                    EventBus.shared.post(.clipboardUpdated(text: str))
                }
            }
        }
    }

    public func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    public func compactView() -> AnyView {
        AnyView(
            HStack(spacing: 6) {
                Image(systemName: "doc.on.clipboard.fill")
                    .foregroundColor(.teal)
                    .font(.system(size: 12))
                Text(latestSnippet)
                    .font(.system(size: 11, weight: .medium))
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
                    Image(systemName: "doc.on.clipboard.fill")
                        .foregroundColor(.teal)
                    Text("Clipboard History")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(history) { item in
                            ClipboardItemRowView(item: item, onCopy: { [weak self] content in
                                self?.copyToClipboard(content)
                            })
                        }
                    }
                }
            }
            .padding(14)
        )
    }

    public func minimalView() -> AnyView {
        AnyView(Image(systemName: "doc.on.clipboard").foregroundColor(.teal))
    }
}

// MARK: - Interactive Row Component with Animated "Copied!" Feedback
struct ClipboardItemRowView: View {
    let item: ClipboardItem
    let onCopy: (String) -> Void
    
    @State private var isCopied: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Text(item.content)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer()

            Button(action: performCopy) {
                HStack(spacing: 4) {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 9, weight: .bold))
                    Text(isCopied ? "Copied!" : "Copy")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(isCopied ? .green : .teal)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isCopied ? Color.green.opacity(0.18) : Color.teal.opacity(0.12))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(6)
        .background(Color.white.opacity(0.08))
        .cornerRadius(6)
    }

    private func performCopy() {
        onCopy(item.content)
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)

        withAnimation(.easeInOut(duration: 0.15)) {
            isCopied = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeInOut(duration: 0.2)) {
                isCopied = false
            }
        }
    }
}
