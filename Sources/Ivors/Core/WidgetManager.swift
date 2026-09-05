import Foundation
import SwiftUI
import Combine

public final class WidgetManager: ObservableObject {
    public static let shared = WidgetManager()

    @Published public private(set) var registeredWidgets: [DynamicIslandWidget] = []
    @Published public var activeWidget: DynamicIslandWidget?
    @Published public var secondaryWidget: DynamicIslandWidget?
    @Published public var activeState: IslandState = .minimal
    @Published public var isTemporaryPopupActive: Bool = false
    @Published public var isDragTargeted: Bool = false
    @Published public var selectedTab: Int = 0

    private var cancellables = Set<AnyCancellable>()
    private var popupTimer: Timer?
    private var prePopupActiveWidget: DynamicIslandWidget?

    private init() {
        setupEventBusObservers()
    }

    public func register(_ widget: DynamicIslandWidget) {
        if !registeredWidgets.contains(where: { $0.id == widget.id }) {
            registeredWidgets.append(widget)
            sortAndEvaluateActiveWidget()
        }
    }

    public func registerAll(_ widgets: [DynamicIslandWidget]) {
        for widget in widgets {
            register(widget)
        }
    }

    public func setPrimaryWidget(_ id: String) {
        if let widget = registeredWidgets.first(where: { $0.id == id }) {
            activeWidget = widget
            sortAndEvaluateActiveWidget()
        }
    }

    public func triggerTemporaryPopup(widgetId: String = "battery", duration: Double = 2.8) {
        // Require full access (authenticated & active trial or pro license) for popups!
        guard TrialManager.shared.hasFullAccess else { return }

        // If the user has expanded or maximized the Dynamic Island, do NOT interrupt them!
        if activeState == .expanded || activeState == .maximized {
            return
        }

        popupTimer?.invalidate()

        if !isTemporaryPopupActive {
            prePopupActiveWidget = activeWidget
        }

        isTemporaryPopupActive = true

        // Force switch activeWidget to target event widget ("battery") so event badge is displayed!
        if let eventWidget = registeredWidgets.first(where: { $0.id == widgetId }) {
            activeWidget = eventWidget
        }

        // Smoothly expand Dynamic Island to 30-40% height (.alertPopup) from behind camera notch!
        withAnimation(AnimationController.defaultSpring) {
            activeState = .alertPopup
        }

        popupTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            withAnimation(AnimationController.defaultSpring) {
                self.isTemporaryPopupActive = false
                if let previous = self.prePopupActiveWidget {
                    self.activeWidget = previous
                }
                self.sortAndEvaluateActiveWidget()
            }
        }
    }

    public func switchToNextWidget() {
        let enabled = registeredWidgets.filter { SettingsManager.shared.isWidgetEnabled($0.id) }
        guard !enabled.isEmpty else { return }

        if let current = activeWidget, let currentIndex = enabled.firstIndex(where: { $0.id == current.id }) {
            let nextIndex = (currentIndex + 1) % enabled.count
            activeWidget = enabled[nextIndex]
        } else {
            activeWidget = enabled.first
        }
        sortAndEvaluateActiveWidget()
    }

    public func switchToPreviousWidget() {
        let enabled = registeredWidgets.filter { SettingsManager.shared.isWidgetEnabled($0.id) }
        guard !enabled.isEmpty else { return }

        if let current = activeWidget, let currentIndex = enabled.firstIndex(where: { $0.id == current.id }) {
            let prevIndex = (currentIndex - 1 + enabled.count) % enabled.count
            activeWidget = enabled[prevIndex]
        } else {
            activeWidget = enabled.first
        }
        sortAndEvaluateActiveWidget()
    }

    public func sortAndEvaluateActiveWidget() {
        if isTemporaryPopupActive { return } // Keep temporary popup active until timer completes!

        let enabled = registeredWidgets.filter { SettingsManager.shared.isWidgetEnabled($0.id) }
        let sorted = enabled.sorted { $0.priority > $1.priority }

        if activeWidget == nil {
            activeWidget = sorted.first
        }

        if sorted.count > 1 {
            secondaryWidget = sorted.first(where: { $0.id != activeWidget?.id })
        } else {
            secondaryWidget = nil
        }

        let isMediaPlaying = MediaManager.shared.currentTrack.isPlaying
        let alwaysShowCompact = SettingsManager.shared.alwaysShowCompactBar

        // If user does not have full access (not signed in or trial expired), keep island locked/minimal!
        let targetState: IslandState
        if !TrialManager.shared.hasFullAccess {
            targetState = .minimal
        } else {
            targetState = (isMediaPlaying || alwaysShowCompact) ? .compact : .minimal
        }

        // Transition from halfExpanded or temporary states back to target state (.compact or .minimal)
        if activeState != .expanded && activeState != .maximized {
            withAnimation(AnimationController.defaultSpring) {
                activeState = targetState
            }
        }
    }

    private func setupEventBusObservers() {
        EventBus.shared.publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (event: SystemEvent) in
                switch event {
                case .mediaStateChanged:
                    self?.sortAndEvaluateActiveWidget()

                default:
                    break
                }
            }
            .store(in: &cancellables)
    }
}
