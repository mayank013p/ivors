import SwiftUI
import Combine

public final class VolumeHUDWidget: DynamicIslandWidget, ObservableObject {
    public let id: String = "volume_hud"
    public let name: String = "Volume HUD"
    public var priority: Int { isShowing ? 150 : 0 }
    public var isVisible: Bool { isShowing }
    public var preferredCompactWidth: CGFloat { 180 }
    public var preferredExpandedSize: CGSize { CGSize(width: 280, height: 70) }

    @Published public var volumeLevel: Float = 0.65
    @Published public var isShowing: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private var hideTimer: Timer?

    public init() {
        EventBus.shared.publisher
            .sink { [weak self] event in
                if case .volumeChanged(let level) = event {
                    self?.trigger(level: level)
                }
            }
            .store(in: &cancellables)
    }

    public func trigger(level: Float) {
        self.volumeLevel = level
        self.isShowing = true
        WidgetManager.shared.sortAndEvaluateActiveWidget()

        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.isShowing = false
            WidgetManager.shared.sortAndEvaluateActiveWidget()
        }
    }

    public func compactView() -> AnyView {
        AnyView(
            HStack(spacing: 8) {
                Image(systemName: volumeIcon(volumeLevel))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.2))
                        Capsule().fill(Color.white).frame(width: geo.size.width * CGFloat(self.volumeLevel))
                    }
                }
                .frame(height: 5)
            }
            .padding(.horizontal, 8)
        )
    }

    public func expandedView() -> AnyView { compactView() }
    public func minimalView() -> AnyView {
        AnyView(Image(systemName: volumeIcon(volumeLevel)).foregroundColor(.white))
    }

    private func volumeIcon(_ level: Float) -> String {
        if level <= 0 { return "speaker.slash.fill" }
        if level < 0.33 { return "speaker.wave.1.fill" }
        if level < 0.66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
}

public final class BrightnessHUDWidget: DynamicIslandWidget, ObservableObject {
    public let id: String = "brightness_hud"
    public let name: String = "Brightness HUD"
    public var priority: Int { isShowing ? 150 : 0 }
    public var isVisible: Bool { isShowing }
    public var preferredCompactWidth: CGFloat { 180 }
    public var preferredExpandedSize: CGSize { CGSize(width: 280, height: 70) }

    @Published public var brightnessLevel: Float = 0.8
    @Published public var isShowing: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private var hideTimer: Timer?

    public init() {
        EventBus.shared.publisher
            .sink { [weak self] event in
                if case .brightnessChanged(let level) = event {
                    self?.trigger(level: level)
                }
            }
            .store(in: &cancellables)
    }

    public func trigger(level: Float) {
        self.brightnessLevel = level
        self.isShowing = true
        WidgetManager.shared.sortAndEvaluateActiveWidget()

        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.isShowing = false
            WidgetManager.shared.sortAndEvaluateActiveWidget()
        }
    }

    public func compactView() -> AnyView {
        AnyView(
            HStack(spacing: 8) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.yellow)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.2))
                        Capsule().fill(Color.yellow).frame(width: geo.size.width * CGFloat(self.brightnessLevel))
                    }
                }
                .frame(height: 5)
            }
            .padding(.horizontal, 8)
        )
    }

    public func expandedView() -> AnyView { compactView() }
    public func minimalView() -> AnyView {
        AnyView(Image(systemName: "sun.max.fill").foregroundColor(.yellow))
    }
}
