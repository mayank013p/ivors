import AppKit
import SwiftUI
import Combine

public final class WindowManager: ObservableObject {
    public static let shared = WindowManager()

    public var panel: DynamicIslandPanel?
    private var cancellables = Set<AnyCancellable>()
    private var globalClickMonitor: Any?
    private var keyMonitor: Any?
    private var scrollMonitor: Any?

    private var accumulatedDeltaX: CGFloat = 0
    private var hasTriggeredInGesture: Bool = false

    private init() {}

    public func setupPanel() {
        IslandLayoutEngine.shared.updateNotchGeometry()

        let initialFrame = IslandLayoutEngine.shared.calculatePanelFrame(
            for: WidgetManager.shared.activeState,
            activeWidget: WidgetManager.shared.activeWidget
        )

        let islandPanel = DynamicIslandPanel(contentRect: initialFrame)

        let rootView = DynamicIslandView { [weak self] in
            self?.toggleIslandState()
        }

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.translatesAutoresizingMaskIntoConstraints = true
        hostingView.autoresizingMask = [.width, .height]

        let container = IslandContainerView(frame: NSRect(origin: .zero, size: initialFrame.size))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor
        container.autoresizingMask = [.width, .height]
        container.addSubview(hostingView)
        hostingView.frame = container.bounds

        islandPanel.contentView = container
        islandPanel.setFrame(initialFrame, display: true)
        islandPanel.orderFrontRegardless()
        self.panel = islandPanel

        setupObservers()
        setupEventMonitors()
    }

    public func updateFrame(for state: IslandState, animated: Bool = true) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let panel = self.panel else { return }
            let newFrame = IslandLayoutEngine.shared.calculatePanelFrame(
                for: state,
                activeWidget: WidgetManager.shared.activeWidget
            )
            guard panel.frame != newFrame else { return }

            if animated {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.28
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    context.allowsImplicitAnimation = true
                    panel.animator().setFrame(newFrame, display: true)
                    panel.contentView?.animator().frame = NSRect(origin: .zero, size: newFrame.size)
                    panel.contentView?.subviews.forEach { $0.animator().frame = NSRect(origin: .zero, size: newFrame.size) }
                }
            } else {
                panel.setFrame(newFrame, display: true)
                panel.contentView?.frame = NSRect(origin: .zero, size: newFrame.size)
                panel.contentView?.subviews.forEach { $0.frame = NSRect(origin: .zero, size: newFrame.size) }
            }
        }
    }

    public func toggleIslandState() {
        let current = WidgetManager.shared.activeState
        let next: IslandState = (current == .expanded || current == .maximized) ? (MediaManager.shared.currentTrack.isPlaying || SettingsManager.shared.alwaysShowCompactBar ? .compact : .minimal) : .expanded
        withAnimation(AnimationController.defaultSpring) {
            WidgetManager.shared.activeState = next
        }
    }

    private func setupObservers() {
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in
                IslandLayoutEngine.shared.updateNotchGeometry()
                if let state = WidgetManager.shared.activeState as IslandState? {
                    self?.updateFrame(for: state)
                }
            }
            .store(in: &cancellables)

        WidgetManager.shared.$activeState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updateFrame(for: state)
            }
            .store(in: &cancellables)

        WidgetManager.shared.$activeWidget
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                if let state = WidgetManager.shared.activeState as IslandState? {
                    self?.updateFrame(for: state)
                }
            }
            .store(in: &cancellables)

        SettingsManager.shared.$alwaysShowCompactBar
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                WidgetManager.shared.sortAndEvaluateActiveWidget()
                if let state = WidgetManager.shared.activeState as IslandState? {
                    self?.updateFrame(for: state)
                }
            }
            .store(in: &cancellables)
    }

    private func setupEventMonitors() {
        // 1. Click-Outside Monitor to Auto-Collapse Expanded Panel
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let panel = self.panel else { return }

            let state = WidgetManager.shared.activeState
            let isDragTargeted = WidgetManager.shared.isDragTargeted

            // Only lock open while a drag operation is actively hovering over the island drop zone
            let shouldLockOpen = isDragTargeted && (state == .maximized)

            if (state == .expanded || state == .maximized) && !shouldLockOpen {
                let expandedBounds = panel.frame.insetBy(dx: -15, dy: -15)
                let mouseLocation = NSEvent.mouseLocation

                if !NSMouseInRect(mouseLocation, expandedBounds, false) {
                    DispatchQueue.main.async {
                        withAnimation(AnimationController.defaultSpring) {
                            WidgetManager.shared.activeState = (MediaManager.shared.currentTrack.isPlaying || SettingsManager.shared.alwaysShowCompactBar) ? .compact : .minimal
                        }
                    }
                }
            }
        }

        // 2. ESC Key Monitor
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // ESC key
                let state = WidgetManager.shared.activeState
                if state == .expanded || state == .maximized {
                    DispatchQueue.main.async {
                        withAnimation(AnimationController.defaultSpring) {
                            WidgetManager.shared.activeState = (MediaManager.shared.currentTrack.isPlaying || SettingsManager.shared.alwaysShowCompactBar) ? .compact : .minimal
                        }
                    }
                    return nil
                }
            }
            return event
        }

        // 3. Bulletproof 60fps Trackpad 2-Finger Horizontal Scroll/Swipe Monitor
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self = self, let panel = self.panel else { return event }

            if WidgetManager.shared.activeState == .expanded {
                let mouseLocation = NSEvent.mouseLocation
                let screenTopMax = (NSScreen.main?.frame.maxY ?? 1000)
                let isTopScreenArea = mouseLocation.y > (screenTopMax - 260)
                let panelBounds = panel.frame.insetBy(dx: -40, dy: -40)

                if isTopScreenArea || NSMouseInRect(mouseLocation, panelBounds, false) {
                    let deltaX = event.hasPreciseScrollingDeltas ? event.scrollingDeltaX : event.deltaX

                    if event.phase == .began || event.momentumPhase == .began {
                        self.accumulatedDeltaX = 0
                        self.hasTriggeredInGesture = false
                    }

                    self.accumulatedDeltaX += deltaX

                    if !self.hasTriggeredInGesture {
                        if self.accumulatedDeltaX < -12.0 {
                            self.hasTriggeredInGesture = true
                            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                            DispatchQueue.main.async {
                                withAnimation(AnimationController.defaultSpring) {
                                    WidgetManager.shared.switchToNextWidget()
                                }
                            }
                            return nil
                        } else if self.accumulatedDeltaX > 12.0 {
                            self.hasTriggeredInGesture = true
                            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                            DispatchQueue.main.async {
                                withAnimation(AnimationController.defaultSpring) {
                                    WidgetManager.shared.switchToPreviousWidget()
                                }
                            }
                            return nil
                        }
                    }

                    if event.phase == .ended || event.momentumPhase == .ended {
                        self.accumulatedDeltaX = 0
                        self.hasTriggeredInGesture = false
                    }
                }
            }
            return event
        }
    }

    deinit {
        if let globalClickMonitor = globalClickMonitor {
            NSEvent.removeMonitor(globalClickMonitor)
        }
        if let keyMonitor = keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        if let scrollMonitor = scrollMonitor {
            NSEvent.removeMonitor(scrollMonitor)
        }
    }
}
