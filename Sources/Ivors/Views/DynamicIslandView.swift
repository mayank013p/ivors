import SwiftUI
import Combine
import AppKit
import UniformTypeIdentifiers

// MARK: - Mathematically Perfect Smooth Dynamic Island Notch & Floating Pill Shape
// MARK: - Mathematically Perfect Smooth Dynamic Island Notch & Floating Pill Shape
public struct NotchIslandShape: Shape {
    public var hasNotch: Bool = true
    public var notchWidth: CGFloat = 200.0
    public var notchHeight: CGFloat = 32.0
    public var earRadius: CGFloat = 14.0
    public var cornerRadius: CGFloat = 18.0

    public func path(in rect: CGRect) -> Path {
        if !hasNotch {
            return RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).path(in: rect)
        }
        var path = Path()
        let minX = rect.minX
        let maxX = rect.maxX
        let minY = rect.minY
        let maxY = rect.maxY
        let r = cornerRadius

        path.move(to: CGPoint(x: minX, y: minY))
        path.addLine(to: CGPoint(x: maxX, y: minY))
        path.addLine(to: CGPoint(x: maxX, y: maxY - r))
        path.addArc(center: CGPoint(x: maxX - r, y: maxY - r), radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: minX + r, y: maxY))
        path.addArc(center: CGPoint(x: minX + r, y: maxY - r), radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: minX, y: minY))
        path.closeSubpath()
        return path
    }
}

public struct DynamicIslandView: View {
    @ObservedObject var widgetManager = WidgetManager.shared
    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var layoutEngine = IslandLayoutEngine.shared
    @ObservedObject var hudManager = VolumeBrightnessHUDManager.shared
    @ObservedObject var mediaManager = MediaManager.shared

    @State private var isHovered: Bool = false
    @State private var dragOffset: CGFloat = 0
    @State private var swipingTargetTitle: String? = nil
    @State private var swipingTargetIcon: String? = nil
    @State private var isDropTargeted: Bool = false

    // Pending auto-hide timer work item to prevent race conditions during repeated hovering
    @State private var autoHideWorkItem: DispatchWorkItem? = nil

    var onExpandToggle: () -> Void

    @State private var isAirDropTargeted: Bool = false

    let mainWidgetIds = ["music", "battery", "airdrop", "calendar", "clock", "quick_actions", "timer", "connectivity", "clipboard"]

    // The left-side widget: always music if playing, otherwise active widget
    private var leftWidget: DynamicIslandWidget? {
        if mediaManager.currentTrack.isPlaying {
            return widgetManager.registeredWidgets.first(where: { $0.id == "music" })
        }
        return widgetManager.activeWidget
    }

    // The right-side widget: the active/switching widget if music is on left, otherwise secondary
    private var rightWidget: DynamicIslandWidget? {
        if mediaManager.currentTrack.isPlaying {
            return widgetManager.activeWidget?.id == "music"
                ? widgetManager.secondaryWidget
                : widgetManager.activeWidget
        }
        if let sec = widgetManager.secondaryWidget, sec.id != widgetManager.activeWidget?.id {
            return sec
        }
        return nil
    }

    private var containerHeight: CGFloat {
        switch widgetManager.activeState {
        case .maximized:
            return layoutEngine.maximizedPanelHeight
        case .expanded:
            return layoutEngine.expandedPanelHeight
        case .alertPopup:
            return layoutEngine.alertPanelHeight
        case .compact:
            return layoutEngine.compactPanelHeight
        case .hidden, .minimal:
            return layoutEngine.hasNotch ? layoutEngine.notchHeight : 32.0
        }
    }

    public var body: some View {
        let state = widgetManager.activeState
        let islandShape = NotchIslandShape(
            hasNotch: layoutEngine.hasNotch,
            notchWidth: layoutEngine.notchWidth,
            notchHeight: layoutEngine.notchHeight,
            earRadius: 14.0,
            cornerRadius: state == .compact ? 18.0 : (state == .alertPopup ? 24.0 : (layoutEngine.hasNotch ? state.cornerRadius : 24.0))
        )

        ZStack(alignment: .top) {
            // Single Continuous Island Background (Morphs seamlessly across all 5 states!)
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(state == .hidden ? 0.0 : 0.85)

                Color.black.opacity(state == .hidden ? 0.0 : (layoutEngine.hasNotch ? settings.blurIntensity : 0.90))
            }
            .clipShape(islandShape)
            .overlay(
                islandShape.stroke(Color.white.opacity(state == .hidden ? 0.0 : (layoutEngine.hasNotch ? 0.12 : 0.16)), lineWidth: layoutEngine.hasNotch ? 0.6 : 0.8)
            )
            .shadow(color: Color.black.opacity(state == .hidden ? 0.0 : 0.45), radius: layoutEngine.hasNotch ? 8 : 14, x: 0, y: layoutEngine.hasNotch ? 2 : 5)

            // Internal Content Area
            ZStack(alignment: .top) {
                if state == .alertPopup {
                    VStack(spacing: 0) {
                        if layoutEngine.hasNotch {
                            Spacer().frame(height: layoutEngine.notchHeight + 4)
                        } else {
                            Spacer().frame(height: 6)
                        }

                        if let batteryWidget = widgetManager.registeredWidgets.first(where: { $0.id == "battery" }) as? BatteryWidget,
                           let note = batteryWidget.currentNotification {
                            HStack(spacing: 12) {
                                if let art = note.artwork {
                                    Image(nsImage: art)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 28, height: 28)
                                        .cornerRadius(6)
                                } else {
                                    AnimatedBadgeIcon(icon: note.icon, color: colorForType(note.type))
                                        .scaleEffect(1.0)
                                        .frame(width: 28, height: 28)
                                }

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(note.title)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    Text(note.message)
                                        .font(.system(size: 10.5, weight: .medium))
                                        .foregroundColor(.white.opacity(0.85))
                                        .lineLimit(1)
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 4)
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        }
                    }
                    .transition(.opacity)
                } else if state == .compact {
                    if layoutEngine.hasNotch {
                        HStack(spacing: 0) {
                            Group {
                                if let left = leftWidget {
                                    left.compactView()
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Spacer().frame(width: layoutEngine.notchWidth + 12)

                            Group {
                                if mediaManager.currentTrack.isPlaying {
                                    if let right = rightWidget {
                                        right.compactView()
                                    } else {
                                        AudioEqualizerView(isPlaying: true)
                                            .frame(width: 14, height: 12)
                                    }
                                } else {
                                    if let right = rightWidget {
                                        right.compactView()
                                    } else if let primary = widgetManager.activeWidget {
                                        CompactRightAccessoryView(widget: primary)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .frame(height: layoutEngine.notchHeight, alignment: .center)
                        .padding(.horizontal, 14)
                        .padding(.top, 4)
                        .transition(.opacity)
                    } else {
                        HStack(spacing: 10) {
                            if let left = leftWidget {
                                left.compactView()
                            }
                            Spacer(minLength: 8)
                            if mediaManager.currentTrack.isPlaying {
                                if let right = rightWidget {
                                    right.compactView()
                                }
                                AudioEqualizerView(isPlaying: true)
                                    .frame(width: 14, height: 12)
                            } else {
                                if let right = rightWidget {
                                    right.compactView()
                                } else if let primary = widgetManager.activeWidget {
                                    CompactRightAccessoryView(widget: primary)
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 38, alignment: .center)
                        .transition(.opacity)
                    }
                } else if state == .expanded {
                    VStack(spacing: 0) {
                        if layoutEngine.hasNotch {
                            Spacer().frame(height: layoutEngine.notchHeight + 2)
                        } else {
                            Spacer().frame(height: 6)
                        }

                        HStack(spacing: 6) {
                            if let widget = widgetManager.activeWidget {
                                HStack(spacing: 6) {
                                    Image(systemName: swipingTargetIcon ?? widgetIconName(widget.id))
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(settings.accentColor)
                                    Text(swipingTargetTitle ?? widgetShortTitle(widget.id))
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white.opacity(0.95))
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            Button(action: {
                                withAnimation(AnimationController.defaultSpring) {
                                    widgetManager.activeState = (widgetManager.activeState == .maximized) ? .expanded : .maximized
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: widgetManager.activeState == .maximized ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(settings.accentColor)
                                    Text(widgetManager.activeState == .maximized ? "Minimize Bar" : "Maximize Bar")
                                        .font(.system(size: 9.5, weight: .bold))
                                        .foregroundColor(.white.opacity(0.95))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.12))
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)

                            Button(action: {
                                withAnimation(AnimationController.defaultSpring) {
                                    settings.alwaysShowCompactBar.toggle()
                                    widgetManager.sortAndEvaluateActiveWidget()
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: settings.alwaysShowCompactBar ? "checkmark.square.fill" : "square")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(settings.alwaysShowCompactBar ? settings.accentColor : .white.opacity(0.4))
                                    Text("Keep Bar Visible")
                                        .font(.system(size: 9.5, weight: .bold))
                                        .foregroundColor(.white.opacity(0.85))
                                }
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3.5)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(height: 22)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 2)

                        ZStack(alignment: .top) {
                            TrackpadSwipeGestureView(
                                onSwipeLeft: {
                                    withAnimation(AnimationController.defaultSpring) {
                                        widgetManager.switchToNextWidget()
                                        swipingTargetTitle = nil; swipingTargetIcon = nil
                                    }
                                },
                                onSwipeRight: {
                                    withAnimation(AnimationController.defaultSpring) {
                                        widgetManager.switchToPreviousWidget()
                                        swipingTargetTitle = nil; swipingTargetIcon = nil
                                    }
                                }
                            )

                            if !TrialManager.shared.hasFullAccess {
                                VStack(spacing: 6) {
                                    Image(systemName: "lock.shield.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.orange)
                                    if !AuthManager.shared.isAuthenticated && !TrialManager.shared.isLicenseActivated {
                                        Text("Sign In or Register Required")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                        Text("Sign in with your email to start your 14-day free trial.")
                                            .font(.system(size: 10))
                                            .foregroundColor(.white.opacity(0.7))
                                    } else {
                                        Text("14-Day Free Trial Expired")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                        Text("Upgrade to Ivors Pro to continue using all widgets.")
                                            .font(.system(size: 10))
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                    HStack(spacing: 8) {
                                        Button("Buy Pro License") {
                                            if let url = URL(string: settings.razorpayPaymentPageURL) {
                                                NSWorkspace.shared.open(url)
                                            }
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(.orange)
                                        .font(.system(size: 10, weight: .bold))
                                    }
                                }
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else if let widget = widgetManager.activeWidget {
                                widget.expandedView()
                                    .offset(x: dragOffset)
                                    .id(widget.id)
                                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                            }

                            if let targetTitle = swipingTargetTitle, let targetIcon = swipingTargetIcon {
                                HStack(spacing: 6) {
                                    Image(systemName: dragOffset < 0 ? "chevron.right.circle.fill" : "chevron.left.circle.fill")
                                        .foregroundColor(settings.accentColor)
                                    Image(systemName: targetIcon).foregroundColor(.white)
                                    Text(targetTitle)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.black.opacity(0.85)).overlay(Capsule().stroke(settings.accentColor, lineWidth: 1)))
                                .offset(y: 8)
                                .transition(.opacity.combined(with: .scale))
                            }
                        }
                        .frame(width: IslandLayoutEngine.expandedWidth, height: 140, alignment: .top)

                        Spacer(minLength: 0)

                        let enabledWidgets = widgetManager.registeredWidgets.filter { mainWidgetIds.contains($0.id) && settings.isWidgetEnabled($0.id) }
                        HStack(spacing: 6) {
                            Spacer()
                            ForEach(enabledWidgets, id: \.id) { w in
                                Button(action: {
                                    withAnimation(AnimationController.defaultSpring) {
                                        widgetManager.setPrimaryWidget(w.id)
                                    }
                                }) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(widgetManager.activeWidget?.id == w.id ? settings.accentColor.opacity(0.35) : Color.white.opacity(0.08))
                                            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                .stroke(widgetManager.activeWidget?.id == w.id ? settings.accentColor : Color.clear, lineWidth: 1))
                                        Image(systemName: widgetIconName(w.id))
                                            .font(.system(size: 10, weight: widgetManager.activeWidget?.id == w.id ? .bold : .medium))
                                            .foregroundColor(widgetManager.activeWidget?.id == w.id ? .white : .white.opacity(0.6))
                                    }
                                    .frame(width: 23, height: 23)
                                }
                                .buttonStyle(.plain)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 8)
                    }
                    .transition(.opacity)
                } else if state == .maximized {
                    MaximizedTheaterDashboardView()
                        .transition(.opacity)
                }
            }
        }
        .frame(width: (state == .maximized) ? 780.0 : IslandLayoutEngine.expandedWidth, height: containerHeight, alignment: .top)
        .contentShape(Rectangle())
        .animation(AnimationController.defaultSpring, value: state)
        .animation(AnimationController.interactiveSpring, value: isHovered)
        .onDrop(of: [.fileURL, .item, .data], delegate: NotchFileDropDelegate(isTargeted: $isDropTargeted))
        .onChange(of: isDropTargeted) { _, targeted in
            if targeted {
                withAnimation(AnimationController.defaultSpring) {
                    widgetManager.activeState = .maximized
                }
            }
        }
        .onHover { hovering in
            isHovered = hovering
            if settings.enableHoverExpand && widgetManager.activeState != .maximized {
                if hovering {
                    // Cancel any pending auto-hide collapse timers immediately on hover in!
                    autoHideWorkItem?.cancel()
                    autoHideWorkItem = nil
                    withAnimation(AnimationController.defaultSpring) {
                        widgetManager.activeState = .expanded
                    }
                } else {
                    // Cancel previous timer and schedule clean auto-hide collapse
                    autoHideWorkItem?.cancel()
                    let delay = settings.autoHideDelay
                    let workItem = DispatchWorkItem {
                        withAnimation(AnimationController.defaultSpring) {
                            if !self.isHovered && widgetManager.activeState != .maximized {
                                widgetManager.activeState = (MediaManager.shared.currentTrack.isPlaying || self.settings.alwaysShowCompactBar) ? .compact : .minimal
                            }
                        }
                    }
                    autoHideWorkItem = workItem
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
                }
            }
        }
        .onTapGesture {
            if widgetManager.activeState != .maximized && settings.enableClickToggle {
                onExpandToggle()
            }
        }
        .onDrop(of: [.fileURL], isTargeted: Binding(
            get: { widgetManager.isDragTargeted },
            set: { isTargeted in
                widgetManager.isDragTargeted = isTargeted
                if isTargeted {
                    withAnimation(AnimationController.defaultSpring) {
                        widgetManager.activeState = .maximized
                        widgetManager.selectedTab = 2
                    }
                }
            }
        )) { providers in
            let group = DispatchGroup()
            var droppedURLs: [URL] = []
            for provider in providers {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                    defer { group.leave() }
                    if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        droppedURLs.append(url)
                    } else if let url = item as? URL {
                        droppedURLs.append(url)
                    }
                }
            }
            group.notify(queue: .main) {
                if !droppedURLs.isEmpty {
                    FileStashManager.shared.addFiles(droppedURLs)
                }
            }
            return true
        }
    }

    private func updateSwipingTargetPreview(translationX: CGFloat) {
        let enabled = widgetManager.registeredWidgets.filter { mainWidgetIds.contains($0.id) && settings.isWidgetEnabled($0.id) }
        guard let current = widgetManager.activeWidget,
              let currentIndex = enabled.firstIndex(where: { $0.id == current.id }),
              !enabled.isEmpty else { return }
        let targetIndex: Int = translationX < 0
            ? (currentIndex + 1) % enabled.count
            : (currentIndex - 1 + enabled.count) % enabled.count
        let target = enabled[targetIndex]
        swipingTargetTitle = widgetShortTitle(target.id)
        swipingTargetIcon = widgetIconName(target.id)
    }

    private func widgetShortTitle(_ id: String) -> String {
        switch id {
        case "airdrop": return "AirDrop"
        case "quick_actions": return "Quick Actions"
        case "music": return "Now Playing"
        case "battery": return "Battery"
        case "calendar": return "Calendar"
        case "clock": return "Clock"
        case "timer": return "Timer"
        case "connectivity": return "Connectivity"
        case "clipboard": return "Clipboard"
        default: return id.capitalized
        }
    }

    private func widgetIconName(_ id: String) -> String {
        switch id {
        case "airdrop": return "shareplay"
        case "quick_actions": return "bolt.horizontal.fill"
        case "music": return "music.note"
        case "battery": return "battery.100"
        case "calendar": return "calendar"
        case "clock": return "clock.fill"
        case "timer": return "timer"
        case "connectivity": return "antenna.radiowaves.left.and.right"
        case "clipboard": return "doc.on.clipboard"
        default: return "app.dashed"
        }
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

// MARK: - Trackpad swipe listener
struct TrackpadSwipeGestureView: NSViewRepresentable {
    var onSwipeLeft: () -> Void
    var onSwipeRight: () -> Void

    func makeNSView(context: Context) -> TrackpadSwipeNSView {
        let v = TrackpadSwipeNSView()
        v.onSwipeLeft = onSwipeLeft; v.onSwipeRight = onSwipeRight
        return v
    }

    func updateNSView(_ nsView: TrackpadSwipeNSView, context: Context) {
        nsView.onSwipeLeft = onSwipeLeft; nsView.onSwipeRight = onSwipeRight
    }
}

class TrackpadSwipeNSView: NSView {
    var onSwipeLeft: (() -> Void)?
    var onSwipeRight: (() -> Void)?
    private var accumulatedDeltaX: CGFloat = 0
    private var hasTriggeredInGesture: Bool = false

    override func scrollWheel(with event: NSEvent) {
        let deltaX = event.hasPreciseScrollingDeltas ? event.scrollingDeltaX : event.deltaX
        if event.phase == .began || event.momentumPhase == .began {
            accumulatedDeltaX = 0; hasTriggeredInGesture = false
        }
        accumulatedDeltaX += deltaX
        if !hasTriggeredInGesture {
            if accumulatedDeltaX < -16.0 {
                hasTriggeredInGesture = true
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                onSwipeRight?()
            } else if accumulatedDeltaX > 16.0 {
                hasTriggeredInGesture = true
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                onSwipeLeft?()
            }
        }
        if event.phase == .ended || event.momentumPhase == .ended {
            accumulatedDeltaX = 0; hasTriggeredInGesture = false
        }
    }
}

struct CompactRightAccessoryView: View {
    let widget: DynamicIslandWidget
    var body: some View {
        Group {
            if widget.id == "music" {
                AudioEqualizerView(isPlaying: true).frame(width: 14, height: 12)
            } else if widget.id == "battery" {
                Image(systemName: "bolt.fill").foregroundColor(.green).font(.system(size: 11))
            } else {
                Image(systemName: "circle.fill").foregroundColor(.white.opacity(0.3)).font(.system(size: 6))
            }
        }
    }
}

// MARK: - Reference-Inspired Maximized Control Center Dashboard
struct MaximizedTheaterDashboardView: View {
    @ObservedObject var widgetManager = WidgetManager.shared
    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var layoutEngine = IslandLayoutEngine.shared
    @ObservedObject var mediaManager = MediaManager.shared
    @ObservedObject var batteryManager = BatteryManager.shared
    @ObservedObject var systemMonitor = SystemMonitor.shared
    @ObservedObject var caffeineManager = CaffeineManager.shared
    @ObservedObject var pomodoroManager = PomodoroFocusManager.shared
    @ObservedObject var fileStashManager = FileStashManager.shared
    @ObservedObject var lyricsManager = LyricsManager.shared
    @ObservedObject var hudManager = VolumeBrightnessHUDManager.shared

    @State private var isStashDropTargeted: Bool = false
    @State private var isAirDropTargeted: Bool = false

    var body: some View {
        VStack(spacing: 12) {
            headerBar
            tabContent
        }
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private var headerBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                TabIconButton(icon: "house.fill", index: 0, selectedTab: $widgetManager.selectedTab)
                TabIconButton(icon: "timer", index: 1, selectedTab: $widgetManager.selectedTab)
                TabIconButton(icon: "cube.fill", index: 2, selectedTab: $widgetManager.selectedTab)
                TabIconButton(icon: "doc.on.clipboard", index: 3, selectedTab: $widgetManager.selectedTab)
                TabIconButton(icon: "square.and.pencil", index: 4, selectedTab: $widgetManager.selectedTab)
                TabIconButton(icon: "gearshape.fill", index: 5, selectedTab: $widgetManager.selectedTab)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.white.opacity(0.14)).overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.8)))

            Spacer(minLength: layoutEngine.hasNotch ? layoutEngine.notchWidth + 12 : 20)

            HStack(spacing: 8) {
                CircleActionButton(icon: "cup.and.saucer.fill", isActive: caffeineManager.isCaffeineActive) {
                    caffeineManager.toggleCaffeine()
                }

                CircleActionButton(icon: "pin.fill", isActive: settings.alwaysShowCompactBar) {
                    withAnimation(AnimationController.defaultSpring) {
                        settings.alwaysShowCompactBar.toggle()
                    }
                }

                CircleActionButton(icon: "lock.fill", isActive: true) {}

                Button(action: {
                    withAnimation(AnimationController.defaultSpring) {
                        widgetManager.activeState = .expanded
                    }
                }) {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.white.opacity(0.18)).overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 0.8)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, layoutEngine.hasNotch ? layoutEngine.notchHeight + 6 : 14)
        .padding(.bottom, 2)
    }

    @ViewBuilder
    private var tabContent: some View {
        Group {
            switch widgetManager.selectedTab {
            case 0: tab0MusicContent
            case 1: tab1PomodoroContent
            case 2: tab2FileStashContent
            case 3: tab3ClipboardContent
            case 4: tab4TerminalContent
            default: tab5SettingsContent
            }
        }
        .padding(.horizontal, 18)
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private var trackHeaderView: some View {
        HStack(spacing: 12) {
            ZStack {
                if let artwork = mediaManager.currentTrack.artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(colors: [settings.accentColor.opacity(0.8), Color.purple.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: "music.note")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .frame(width: 56, height: 56)
            .shadow(color: Color.black.opacity(0.4), radius: 4, x: 0, y: 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(mediaManager.currentTrack.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(mediaManager.currentTrack.artist.isEmpty ? "Now Playing" : mediaManager.currentTrack.artist)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(1)
                if !mediaManager.currentTrack.album.isEmpty || !mediaManager.currentTrack.playerApp.isEmpty {
                    HStack(spacing: 6) {
                        if !mediaManager.currentTrack.album.isEmpty {
                            Text(mediaManager.currentTrack.album)
                                .font(.system(size: 9.5))
                                .foregroundColor(.white.opacity(0.5))
                                .lineLimit(1)
                        }
                        if !mediaManager.currentTrack.playerApp.isEmpty {
                            HStack(spacing: 4) {
                                Circle().fill(settings.accentColor).frame(width: 4, height: 4)
                                Text("• \(mediaManager.currentTrack.playerApp)")
                                    .font(.system(size: 9.5, weight: .semibold))
                                    .foregroundColor(settings.accentColor)
                            }
                        }
                    }
                }
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var syncedLyricsView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "quote.bubble.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(settings.accentColor)
                Text("Synced Lyrics")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                if lyricsManager.isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                } else if !lyricsManager.lyrics.isEmpty {
                    HStack(spacing: 3) {
                        Button(action: { lyricsManager.timeOffset -= 0.1 }) {
                            Text("-0.1s")
                                .font(.system(size: 8.5, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                        }.buttonStyle(.plain)

                        Text(String(format: "%+.1fs", lyricsManager.timeOffset))
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundColor(settings.accentColor)

                        Button(action: { lyricsManager.timeOffset += 0.1 }) {
                            Text("+0.1s")
                                .font(.system(size: 8.5, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                        }.buttonStyle(.plain)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.white.opacity(0.1)).overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.8)))
                }
            }

            if lyricsManager.lyrics.isEmpty {
                VStack(spacing: 4) {
                    Spacer()
                    Image(systemName: "music.mic")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.3))
                    Text("No Synced Lyrics Available")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                    Text("Playing in \(mediaManager.currentTrack.playerApp.isEmpty ? "Media Player" : mediaManager.currentTrack.playerApp)")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.4))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(lyricsManager.lyrics.enumerated()), id: \.offset) { idx, line in
                                let isCurrent = (idx == lyricsManager.currentLineIndex)
                                Text(line.text)
                                    .font(.system(size: isCurrent ? 13 : 11, weight: isCurrent ? .bold : .medium))
                                    .foregroundColor(isCurrent ? settings.accentColor : .white.opacity(0.45))
                                    .scaleEffect(isCurrent ? 1.02 : 1.0, anchor: .leading)
                                    .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isCurrent)
                                    .id(idx)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .onChange(of: lyricsManager.currentLineIndex) { _, newIndex in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.25)))
    }

    @ViewBuilder
    private var timelineControlsView: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.18)).frame(height: 5)
                    Capsule().fill(settings.accentColor).frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(mediaManager.currentTrack.elapsedTime / max(mediaManager.currentTrack.duration, 1.0)))), height: 5)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let pct = max(0, min(1.0, value.location.x / geo.size.width))
                            let targetTime = pct * mediaManager.currentTrack.duration
                            mediaManager.seek(to: targetTime)
                        }
                )
            }
            .frame(height: 5)

            HStack {
                Text(String(format: "%d:%02d", Int(mediaManager.currentTrack.elapsedTime) / 60, Int(mediaManager.currentTrack.elapsedTime) % 60))
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Text("-\(String(format: "%d:%02d", Int(max(0, mediaManager.currentTrack.duration - mediaManager.currentTrack.elapsedTime)) / 60, Int(max(0, mediaManager.currentTrack.duration - mediaManager.currentTrack.elapsedTime)) % 60))")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }

            HStack(spacing: 16) {
                Spacer()
                Button(action: { mediaManager.previousTrack() }) {
                    ZStack {
                        Circle().fill(Color.white.opacity(0.14))
                        Image(systemName: "backward.fill").font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                    }.frame(width: 30, height: 30)
                }.buttonStyle(.plain)

                Button(action: { mediaManager.togglePlayPause() }) {
                    ZStack {
                        Circle().fill(Color.white)
                        Image(systemName: mediaManager.currentTrack.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.black)
                    }
                    .frame(width: 34, height: 34)
                    .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                }.buttonStyle(.plain)

                Button(action: { mediaManager.nextTrack() }) {
                    ZStack {
                        Circle().fill(Color.white.opacity(0.14))
                        Image(systemName: "forward.fill").font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                    }.frame(width: 30, height: 30)
                }.buttonStyle(.plain)
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var telemetryFallbackView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color.cyan.opacity(0.2))
                    Image(systemName: "cpu")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.cyan)
                }.frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 2) {
                    Text("macOS System Telemetry")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    Text("Apple Silicon Performance")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
                }
            }

            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("CPU LOAD").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Text("\(Int(systemMonitor.cpuUsage))%").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(.cyan)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.12))
                        Capsule().fill(Color.cyan).frame(width: max(4, geo.size.width * CGFloat(systemMonitor.cpuUsage / 100.0)))
                    }
                }.frame(height: 6)

                HStack {
                    Text("MEMORY").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Text("\(Int(systemMonitor.memoryPercentage))%").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(.yellow)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.12))
                        Capsule().fill(Color.yellow).frame(width: max(4, geo.size.width * CGFloat(systemMonitor.memoryPercentage / 100.0)))
                    }
                }.frame(height: 6)
            }
        }
    }

    @ViewBuilder
    private var centerAudioControlCard: some View {
        let deviceName = hudManager.outputDeviceName
        let deviceIcon: String = {
            if deviceName.contains("AirPods") { return "airpodspro" }
            if deviceName.contains("Headphone") { return "headphones" }
            if deviceName.contains("HDMI") || deviceName.contains("Display") { return "tv.fill" }
            return "speaker.wave.2.fill"
        }()
        let volumePct = Int(hudManager.liveSystemVolume * 100)

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "waveform")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(settings.accentColor)
                Text("Audio & Output")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                AudioEqualizerView(isPlaying: mediaManager.currentTrack.isPlaying)
                    .frame(width: 18, height: 14)
            }

            // Live Synced Output Device
            VStack(alignment: .leading, spacing: 6) {
                Text("OUTPUT DEVICE")
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))

                HStack(spacing: 6) {
                    Image(systemName: deviceIcon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(settings.accentColor)
                    Text(deviceName.isEmpty ? "MacBook Speakers" : deviceName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
            }

            // Live Interactive Manageable Volume Slider & Mute Control
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("SYSTEM VOLUME").font(.system(size: 8.5, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.5))
                    Spacer()
                    Text("\(volumePct)%").font(.system(size: 9.5, weight: .bold, design: .monospaced)).foregroundColor(settings.accentColor)
                }

                // Drag gesture interactive volume scrubber
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.14)).frame(height: 7)
                        Capsule()
                            .fill(LinearGradient(colors: [settings.accentColor, settings.accentColor.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(hudManager.liveSystemVolume))), height: 7)
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let pct = Float(max(0, min(1.0, value.location.x / geo.size.width)))
                                hudManager.setSystemVolume(pct)
                            }
                    )
                }
                .frame(height: 7)

                HStack(spacing: 6) {
                    Button(action: {
                        let newVol = max(0.0, hudManager.liveSystemVolume - 0.1)
                        hudManager.setSystemVolume(newVol)
                    }) {
                        Image(systemName: "speaker.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 24, height: 20)
                            .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button(action: {
                        let isMuted = hudManager.liveSystemVolume <= 0.01
                        hudManager.setSystemVolume(isMuted ? 0.5 : 0.0)
                    }) {
                        Text(hudManager.liveSystemVolume <= 0.01 ? "Unmute" : "Mute")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundColor(hudManager.liveSystemVolume <= 0.01 ? .green : .red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button(action: {
                        let newVol = min(1.0, hudManager.liveSystemVolume + 0.1)
                        hudManager.setSystemVolume(newVol)
                    }) {
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 24, height: 20)
                            .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 2)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 4) {
                Text("NOW STREAMING")
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                HStack(spacing: 6) {
                    Image(systemName: "music.note.house.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                    Text(mediaManager.currentTrack.playerApp.isEmpty ? "System Audio" : mediaManager.currentTrack.playerApp)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
        }
        .padding(14)
        .frame(width: 200)
        .frame(maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.09)).overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.12), lineWidth: 0.8)))
    }

    @ViewBuilder
    private var tab0MusicContent: some View {
        let hasActiveTrack = !mediaManager.currentTrack.title.isEmpty && mediaManager.currentTrack.title != "No Track Selected" && mediaManager.currentTrack.title != "Not Playing"
        HStack(spacing: 12) {
            // Card 1: Track Header, Synced Lyrics & Controls (Width: 340)
            VStack(alignment: .leading, spacing: 10) {
                if hasActiveTrack {
                    trackHeaderView
                    syncedLyricsView
                    timelineControlsView
                } else {
                    telemetryFallbackView
                }
            }
            .padding(14)
            .frame(width: 340)
            .frame(maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.09)).overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.12), lineWidth: 0.8)))

            // Card 2: Center Audio & Sound Control Card (Width: 200)
            centerAudioControlCard

            // Card 3: Right Sidebar Telemetry & System Controls (Width: 180)
            VStack(spacing: 8) {
                // Card 1: Power & Battery Management
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle().fill((batteryManager.isCharging ? Color.green : (batteryManager.batteryLevel > 20 ? Color.cyan : Color.red)).opacity(0.18))
                            Image(systemName: batteryManager.isCharging ? "bolt.batteryblock.fill" : "battery.100")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(batteryManager.isCharging ? .green : (batteryManager.batteryLevel > 20 ? .cyan : .red))
                        }
                        .frame(width: 28, height: 28)

                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 4) {
                                Text("\(batteryManager.batteryLevel)%")
                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                if batteryManager.isCharging {
                                    Text("⚡")
                                        .font(.system(size: 10))
                                }
                            }
                            Text(batteryManager.isCharging ? "AC Adapter Connected" : "Running on Battery")
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundColor(.white.opacity(0.65))
                                .lineLimit(1)
                        }
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.12))
                            Capsule().fill(batteryManager.isCharging ? Color.green : (batteryManager.batteryLevel > 20 ? Color.cyan : Color.red))
                                .frame(width: max(4, geo.size.width * CGFloat(batteryManager.batteryLevel) / 100.0))
                        }
                    }
                    .frame(height: 5)
                }
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)).overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 0.8)))

                // Card 2: Live Hardware Performance Telemetry
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "cpu.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.cyan)
                        Text("Live Telemetry")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                    }

                    VStack(spacing: 5) {
                        HStack {
                            Text("CPU").font(.system(size: 8.5, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.6))
                            Spacer()
                            Text("\(Int(systemMonitor.cpuUsage))%").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(.cyan)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.12))
                                Capsule().fill(Color.cyan).frame(width: max(3, geo.size.width * CGFloat(systemMonitor.cpuUsage / 100.0)))
                            }
                        }.frame(height: 4)

                        HStack {
                            Text("RAM").font(.system(size: 8.5, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.6))
                            Spacer()
                            Text("\(Int(systemMonitor.memoryPercentage))%").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(.yellow)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.12))
                                Capsule().fill(Color.yellow).frame(width: max(3, geo.size.width * CGFloat(systemMonitor.memoryPercentage / 100.0)))
                            }
                        }.frame(height: 4)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)).overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 0.8)))

                // Card 3: Live Focus Clock Status
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "timer")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.orange)
                        Text("Focus Timer")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                        Circle().fill(pomodoroManager.isRunning ? Color.orange : Color.gray.opacity(0.5)).frame(width: 6, height: 6)
                    }

                    HStack(spacing: 6) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(pomodoroManager.formattedTime).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(.white)
                            Text(pomodoroManager.currentMode.rawValue).font(.system(size: 8.5)).foregroundColor(.white.opacity(0.5))
                        }
                        Spacer()

                        Button(action: {
                            pomodoroManager.toggleTimer()
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: pomodoroManager.isRunning ? "pause.fill" : "play.fill").font(.system(size: 8.5))
                                Text(pomodoroManager.isRunning ? "Pause" : "Start").font(.system(size: 9, weight: .bold))
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(pomodoroManager.isRunning ? Color.orange : Color.white.opacity(0.15)))
                            .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)).overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 0.8)))

                // Card 4: Quick Action Controls
                HStack(spacing: 6) {
                    Button(action: { caffeineManager.toggleCaffeine() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "cup.and.saucer.fill")
                                .font(.system(size: 10))
                                .foregroundColor(caffeineManager.isCaffeineActive ? .orange : .white.opacity(0.6))
                            Text(caffeineManager.isCaffeineActive ? "Awake" : "Caffeine")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 10).fill(caffeineManager.isCaffeineActive ? Color.orange.opacity(0.3) : Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        withAnimation(AnimationController.defaultSpring) {
                            settings.alwaysShowCompactBar.toggle()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 10))
                                .foregroundColor(settings.alwaysShowCompactBar ? .cyan : .white.opacity(0.6))
                            Text(settings.alwaysShowCompactBar ? "Pinned" : "Pin")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 10).fill(settings.alwaysShowCompactBar ? Color.cyan.opacity(0.3) : Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(width: 180)
            .frame(maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.09)).overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.12), lineWidth: 0.8)))
        }
    }

    @ViewBuilder
    private var pomodoroCardView: some View {
        VStack(spacing: 12) {
            // Header Row: Dynamic Title & Sub-Tool Segmented Selector
            HStack(spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: pomodoroManager.selectedToolTab.icon)
                        .foregroundColor(.orange)
                        .font(.system(size: 12, weight: .bold))
                    Text(pomodoroManager.selectedToolTab == .pomodoro ? "Focus Studio" : (pomodoroManager.selectedToolTab == .timer ? "Timer" : "Stopwatch"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                // Tool Switcher (Pomodoro / Timer / Stopwatch)
                HStack(spacing: 2) {
                    ForEach(TimeToolTab.allCases, id: \.self) { tab in
                        Button(action: {
                            withAnimation(AnimationController.defaultSpring) {
                                pomodoroManager.selectedToolTab = tab
                            }
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 8, weight: .bold))
                                Text(tab.rawValue)
                                    .font(.system(size: 8.5, weight: pomodoroManager.selectedToolTab == tab ? .bold : .medium))
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                            .foregroundColor(pomodoroManager.selectedToolTab == tab ? .black : .white.opacity(0.75))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3.5)
                            .background(Capsule().fill(pomodoroManager.selectedToolTab == tab ? Color.orange : Color.clear))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(2)
                .background(Capsule().fill(Color.white.opacity(0.08)))
                .fixedSize(horizontal: true, vertical: false)
            }

            // Sub-Tool Interactive Content
            Group {
                switch pomodoroManager.selectedToolTab {
                case .pomodoro:
                    pomodoroFocusSubView
                case .timer:
                    countdownTimerSubView
                case .stopwatch:
                    stopwatchSubView
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.09)).overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.12), lineWidth: 0.8)))
    }

    @ViewBuilder
    private var pomodoroFocusSubView: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)

            // Large Circular Dial
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 9)
                Circle()
                    .trim(from: 0, to: CGFloat(pomodoroManager.progress))
                    .stroke(
                        LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 9, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: pomodoroManager.progress)

                VStack(spacing: 3) {
                    Text(pomodoroManager.formattedTime)
                        .font(.system(size: 32, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white)

                    HStack(spacing: 4) {
                        Image(systemName: pomodoroManager.currentMode.icon)
                            .font(.system(size: 9.5))
                            .foregroundColor(.orange)
                        Text(pomodoroManager.currentMode.rawValue)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.75))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2.5)
                    .background(Capsule().fill(Color.white.opacity(0.08)))

                    HStack(spacing: 10) {
                        Button(action: { pomodoroManager.toggleTimer() }) {
                            HStack(spacing: 4) {
                                Image(systemName: pomodoroManager.isRunning ? "pause.fill" : "play.fill")
                                    .font(.system(size: 10, weight: .bold))
                                Text(pomodoroManager.isRunning ? "Pause" : "Start")
                                    .font(.system(size: 10.5, weight: .bold))
                            }
                            .foregroundColor(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.orange))
                        }
                        .buttonStyle(.plain)

                        Button(action: { pomodoroManager.resetTimer() }) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.85))
                                .padding(6)
                                .background(Circle().fill(Color.white.opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                }
            }
            .frame(width: 145, height: 145)

            Spacer(minLength: 0)

            // Mode Selector Pills
            HStack(spacing: 6) {
                ForEach(FocusMode.allCases, id: \.self) { mode in
                    Button(action: { pomodoroManager.setMode(mode) }) {
                        Text(mode == .work ? "25m Work" : (mode == .shortBreak ? "5m Break" : (mode == .longBreak ? "15m Long" : "45m Sprint")))
                            .font(.system(size: 9, weight: pomodoroManager.currentMode == mode ? .bold : .medium))
                            .foregroundColor(pomodoroManager.currentMode == mode ? .white : .white.opacity(0.7))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4.5)
                            .background(Capsule().fill(pomodoroManager.currentMode == mode ? Color.orange : Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Session Info Footer
            HStack(spacing: 8) {
                Image(systemName: pomodoroManager.currentMode.icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.orange)
                VStack(alignment: .leading, spacing: 1) {
                    Text("FOCUS SESSION")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                    Text(pomodoroManager.isRunning ? "\(pomodoroManager.formattedTime) remaining" : "\(pomodoroManager.currentMode.rawValue) (\(pomodoroManager.currentMode.durationMinutes)m)")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundColor(.white)
                }
                Spacer()
                Text("\(Int(pomodoroManager.progress * 100))%")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.orange)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
        }
    }

    @ViewBuilder
    private var countdownTimerSubView: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)

            // Large Circular Countdown Dial
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 9)
                Circle()
                    .trim(from: 0, to: CGFloat(pomodoroManager.customTimerProgress))
                    .stroke(
                        LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 9, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: pomodoroManager.customTimerProgress)

                VStack(spacing: 3) {
                    Text(pomodoroManager.formattedCustomTimer)
                        .font(.system(size: 32, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white)

                    Text(pomodoroManager.isCustomTimerRunning ? "Countdown Running" : "Ready to Start")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundColor(.cyan)

                    HStack(spacing: 8) {
                        Button(action: { pomodoroManager.toggleCustomTimer() }) {
                            HStack(spacing: 4) {
                                Image(systemName: pomodoroManager.isCustomTimerRunning ? "pause.fill" : "play.fill")
                                    .font(.system(size: 10, weight: .bold))
                                Text(pomodoroManager.isCustomTimerRunning ? "Pause" : "Start")
                                    .font(.system(size: 10.5, weight: .bold))
                            }
                            .foregroundColor(.black)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.cyan))
                        }
                        .buttonStyle(.plain)

                        Button(action: { pomodoroManager.addCustomTimerMinutes(1) }) {
                            Text("+1m")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(Color.white.opacity(0.14)))
                        }
                        .buttonStyle(.plain)

                        Button(action: { pomodoroManager.resetCustomTimer() }) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.85))
                                .padding(6)
                                .background(Circle().fill(Color.white.opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                }
            }
            .frame(width: 145, height: 145)

            Spacer(minLength: 0)

            // Preset Capsules
            VStack(spacing: 5) {
                HStack(spacing: 5) {
                    ForEach([1, 3, 5, 10], id: \.self) { mins in
                        Button(action: { pomodoroManager.setCustomTimerDuration(mins * 60) }) {
                            Text("\(mins)m")
                                .font(.system(size: 9.5, weight: pomodoroManager.customTimerDuration == mins * 60 ? .bold : .medium))
                                .foregroundColor(pomodoroManager.customTimerDuration == mins * 60 ? .black : .white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                                .background(RoundedRectangle(cornerRadius: 7).fill(pomodoroManager.customTimerDuration == mins * 60 ? Color.cyan : Color.white.opacity(0.08)))
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 5) {
                    ForEach([15, 20, 30, 60], id: \.self) { mins in
                        Button(action: { pomodoroManager.setCustomTimerDuration(mins * 60) }) {
                            Text(mins >= 60 ? "1 Hr" : "\(mins)m")
                                .font(.system(size: 9.5, weight: pomodoroManager.customTimerDuration == mins * 60 ? .bold : .medium))
                                .foregroundColor(pomodoroManager.customTimerDuration == mins * 60 ? .black : .white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                                .background(RoundedRectangle(cornerRadius: 7).fill(pomodoroManager.customTimerDuration == mins * 60 ? Color.cyan : Color.white.opacity(0.08)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Bottom Status Card
            HStack(spacing: 8) {
                Image(systemName: "hourglass.bottomhalf.filled")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.cyan)
                VStack(alignment: .leading, spacing: 1) {
                    Text("TIMER SCHEDULE")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                    Text(pomodoroManager.isCustomTimerRunning ? "\(pomodoroManager.customTimerRemaining / 60)m \(pomodoroManager.customTimerRemaining % 60)s left" : "Duration: \(pomodoroManager.customTimerDuration / 60) minutes")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundColor(.white)
                }
                Spacer()
                Text("\(Int(pomodoroManager.customTimerProgress * 100))%")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
        }
    }

    @ViewBuilder
    private var stopwatchSubView: some View {
        VStack(spacing: 10) {
            // Dial
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 8)
                Circle()
                    .stroke(LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 8)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text(pomodoroManager.formattedStopwatchTime)
                        .font(.system(size: 26, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white)

                    Text(pomodoroManager.isStopwatchRunning ? "Measuring Elapsed Time" : (pomodoroManager.stopwatchElapsed > 0 ? "Paused" : "Ready"))
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(.green)

                    HStack(spacing: 8) {
                        Button(action: { pomodoroManager.toggleStopwatch() }) {
                            HStack(spacing: 3) {
                                Image(systemName: pomodoroManager.isStopwatchRunning ? "pause.fill" : "play.fill")
                                    .font(.system(size: 9.5, weight: .bold))
                                Text(pomodoroManager.isStopwatchRunning ? "Pause" : "Start")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundColor(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4.5)
                            .background(Capsule().fill(Color.green))
                        }
                        .buttonStyle(.plain)

                        Button(action: { pomodoroManager.recordLap() }) {
                            HStack(spacing: 3) {
                                Image(systemName: "flag.fill")
                                    .font(.system(size: 8.5))
                                Text("Lap")
                                    .font(.system(size: 9.5, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4.5)
                            .background(Capsule().fill(Color.white.opacity(0.15)))
                        }
                        .buttonStyle(.plain)

                        Button(action: { pomodoroManager.resetStopwatch() }) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(.white.opacity(0.85))
                                .padding(5)
                                .background(Circle().fill(Color.white.opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 2)
                }
            }
            .frame(width: 130, height: 130)

            // Lap Times History List
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("LAP SPLITS")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                    Text("\(pomodoroManager.stopwatchLaps.count) Recorded")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                }

                if pomodoroManager.stopwatchLaps.isEmpty {
                    VStack(spacing: 4) {
                        Spacer()
                        Image(systemName: "flag.circle")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.25))
                        Text("Tap 'Lap' while running to capture split times")
                            .font(.system(size: 9.5))
                            .foregroundColor(.white.opacity(0.45))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(pomodoroManager.stopwatchLaps) { lap in
                                HStack {
                                    Text("Lap \(lap.lapNumber)")
                                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("+\(lap.formattedLapTime)")
                                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                                        .foregroundColor(.green)
                                    Spacer()
                                    Text(lap.formattedTotalTime)
                                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3.5)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.06)))
                            }
                        }
                    }
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
        }
    }

    @ViewBuilder
    private var caffeineCardView: some View {
        VStack(alignment: .leading, spacing: 11) {
            // Header Row
            HStack {
                Image(systemName: "cup.and.saucer.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 13, weight: .bold))
                Text("Mac Caffeine Keep Awake")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(caffeineManager.isCaffeineActive ? Color.green : Color.gray.opacity(0.5))
                        .frame(width: 6, height: 6)
                    Text(caffeineManager.isCaffeineActive ? "☕ Active" : "😴 Sleep Allowed")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(caffeineManager.isCaffeineActive ? .orange : .white.opacity(0.5))
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(caffeineManager.isCaffeineActive ? Color.orange.opacity(0.2) : Color.white.opacity(0.08)))
            }

            // Hero Status Card
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(caffeineManager.isCaffeineActive ? Color.orange.opacity(0.2) : Color.white.opacity(0.08))
                        .frame(width: 40, height: 40)
                    Image(systemName: caffeineManager.isCaffeineActive ? "bolt.fill" : "moon.zzz.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(caffeineManager.isCaffeineActive ? .orange : .white.opacity(0.6))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(caffeineManager.isCaffeineActive ? "Sleep Prevention Active" : "Normal Power Management")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundColor(.white)
                    Text(caffeineManager.formattedRemainingTime)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(caffeineManager.isCaffeineActive ? .orange : .white.opacity(0.6))
                }
                Spacer()
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))

            // Duration Presets Section
            VStack(alignment: .leading, spacing: 6) {
                Text("KEEP AWAKE DURATION")
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))

                HStack(spacing: 5) {
                    ForEach([15, 30, 45, 60], id: \.self) { mins in
                        Button(action: { caffeineManager.enableCaffeine(durationMinutes: mins) }) {
                            Text(mins >= 60 ? "1 Hr" : "\(mins)m")
                                .font(.system(size: 9.5, weight: caffeineManager.selectedDurationMinutes == mins ? .bold : .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 5)
                                .background(RoundedRectangle(cornerRadius: 8).fill(caffeineManager.selectedDurationMinutes == mins ? Color.orange : Color.white.opacity(0.08)))
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: { caffeineManager.enableCaffeine(durationMinutes: 120) }) {
                        Text("2 Hr")
                            .font(.system(size: 9.5, weight: caffeineManager.selectedDurationMinutes == 120 ? .bold : .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background(RoundedRectangle(cornerRadius: 8).fill(caffeineManager.selectedDurationMinutes == 120 ? Color.orange : Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)

                    Button(action: { caffeineManager.enableCaffeine(durationMinutes: nil) }) {
                        Text("∞")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 8).fill(caffeineManager.isCaffeineActive && caffeineManager.selectedDurationMinutes == nil ? Color.orange : Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Sleep Prevention Option Toggles
            VStack(spacing: 6) {
                HStack {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                    Text("Prevent Display Sleep & Dimming")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(.white)
                    Spacer()
                    Toggle("", isOn: $caffeineManager.preventDisplaySleep)
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: .orange))
                        .scaleEffect(0.65)
                }

                HStack {
                    Image(systemName: "terminal.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.cyan)
                    Text("Prevent System Idle & Disk Sleep")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                }
            }
            .padding(9)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))

            Spacer(minLength: 0)

            // Master Toggle Button
            Button(action: { caffeineManager.toggleCaffeine() }) {
                HStack(spacing: 6) {
                    Spacer()
                    Image(systemName: caffeineManager.isCaffeineActive ? "stop.fill" : "cup.and.saucer.fill")
                    Text(caffeineManager.isCaffeineActive ? "Turn Off Caffeine" : "Enable Caffeine (Keep Awake)")
                    Spacer()
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(caffeineManager.isCaffeineActive ? .black : .white)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 12).fill(caffeineManager.isCaffeineActive ? Color.orange : Color.white.opacity(0.15)))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.09)).overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.12), lineWidth: 0.8)))
    }

    @ViewBuilder
    private var tab1PomodoroContent: some View {
        HStack(spacing: 14) {
            pomodoroCardView
            caffeineCardView
        }
    }

    private func handleDroppedProviders(_ providers: [NSItemProvider], isAirDrop: Bool) {
        let group = DispatchGroup()
        var urls: [URL] = []
        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                defer { group.leave() }
                if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    urls.append(url)
                } else if let url = item as? URL {
                    urls.append(url)
                }
            }
        }
        group.notify(queue: .main) {
            if !urls.isEmpty {
                if isAirDrop {
                    FileStashManager.shared.triggerAirDropForURLs(urls)
                } else {
                    FileStashManager.shared.addFiles(urls)
                }
            }
        }
    }

    @ViewBuilder
    private var fileStashDropPortalView: some View {
        VStack(spacing: 10) {
            // Zone 1: Drop to Stash Shelf
            VStack(spacing: 8) {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.system(size: 26))
                    .foregroundColor(isStashDropTargeted ? .cyan : settings.accentColor)
                
                Text(isStashDropTargeted ? "Release to Stash File!" : "Drop File to Stash Shelf")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Keeps files handy in shelf & tools")
                    .font(.system(size: 9.5))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isStashDropTargeted ? Color.cyan.opacity(0.2) : Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isStashDropTargeted ? Color.cyan : Color.white.opacity(0.18), style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                    )
            )
            .onDrop(of: [.fileURL], isTargeted: $isStashDropTargeted) { providers in
                handleDroppedProviders(providers, isAirDrop: false)
                return true
            }

            // Zone 2: Instant AirDrop Zone
            VStack(spacing: 8) {
                Image(systemName: "paperplane.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(isAirDropTargeted ? .green : .cyan)
                
                Text(isAirDropTargeted ? "Release for Instant AirDrop!" : "Drop File to AirDrop")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Opens macOS AirDrop share menu directly")
                    .font(.system(size: 9.5))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isAirDropTargeted ? Color.green.opacity(0.2) : Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isAirDropTargeted ? Color.green : Color.cyan.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                    )
            )
            .onDrop(of: [.fileURL], isTargeted: $isAirDropTargeted) { providers in
                handleDroppedProviders(providers, isAirDrop: true)
                return true
            }

            // Action Bar (HEIC to PNG & ZIP)
            HStack(spacing: 8) {
                Button(action: { fileStashManager.convertHeicToPng() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "photo.on.rectangle").font(.system(size: 10))
                        Text("Convert HEIC -> PNG").font(.system(size: 9.5, weight: .bold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.blue))
                    .foregroundColor(.white)
                }.buttonStyle(.plain)

                Button(action: { fileStashManager.createZipArchive() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.zipper").font(.system(size: 10))
                        Text("Compress ZIP").font(.system(size: 9.5, weight: .bold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.15)))
                    .foregroundColor(.white)
                }.buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func stashedItemRow(_ item: StashedFile) -> some View {
        let isPdf = item.name.hasSuffix(".pdf")
        let isZip = item.name.hasSuffix(".zip")
        let isImg = item.name.hasSuffix(".png") || item.name.hasSuffix(".jpg") || item.name.hasSuffix(".heic")

        HStack(spacing: 8) {
            Image(systemName: isPdf ? "doc.text.fill" : (isZip ? "doc.zipper" : (isImg ? "photo.fill" : "doc.fill")))
                .font(.system(size: 14))
                .foregroundColor(isPdf ? .cyan : (isZip ? .orange : (isImg ? .green : .purple)))
            
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(item.fileSizeString)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            Button(action: { fileStashManager.shareAirDrop(item) }) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.cyan)
                    .padding(5)
                    .background(Circle().fill(Color.cyan.opacity(0.15)))
            }.buttonStyle(.plain)

            Button(action: { fileStashManager.revealInFinder(item) }) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(5)
                    .background(Circle().fill(Color.white.opacity(0.1)))
            }.buttonStyle(.plain)

            Button(action: { fileStashManager.removeFile(item) }) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.red.opacity(0.8))
                    .padding(5)
                    .background(Circle().fill(Color.red.opacity(0.12)))
            }.buttonStyle(.plain)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08), lineWidth: 0.5)))
    }

    @ViewBuilder
    private var fileStashShelfListView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "cube.box.fill").foregroundColor(settings.accentColor).font(.system(size: 13, weight: .bold))
                Text("Stashed Shelf Items").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                Spacer()
                Text("\(fileStashManager.stashedFiles.count) Files")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(settings.accentColor)
            }

            Text(fileStashManager.statusMessage)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundColor(.white.opacity(0.65))

            if fileStashManager.stashedFiles.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundColor(.white.opacity(0.2))
                    Text("No stashed items yet")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                    Text("Drag & drop any file over the top notch or into the drop zones")
                        .font(.system(size: 9.5))
                        .foregroundColor(.white.opacity(0.3))
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(fileStashManager.stashedFiles) { item in
                            stashedItemRow(item)
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.09)).overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.12), lineWidth: 0.8)))
    }

    @ViewBuilder
    private var tab2FileStashContent: some View {
        HStack(spacing: 14) {
            fileStashDropPortalView
            fileStashShelfListView
        }
    }

    @ViewBuilder
    private var tab3ClipboardContent: some View {
        HStack(spacing: 14) {
            if let clipWidget = widgetManager.registeredWidgets.first(where: { $0.id == "clipboard" }) {
                clipWidget.expandedView()
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.09)).overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.12), lineWidth: 0.8)))
            }
        }
    }

    @ViewBuilder
    private var tab4TerminalContent: some View {
        HStack(spacing: 14) {
            if let termWidget = widgetManager.registeredWidgets.first(where: { $0.id == "terminal" }) {
                termWidget.expandedView()
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.09)).overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.12), lineWidth: 0.8)))
            }
        }
    }

    @ViewBuilder
    private var tab5SettingsContent: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "cpu").foregroundColor(.cyan).font(.system(size: 14, weight: .bold))
                    Text("Hardware Telemetry").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("CPU LOAD").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.6))
                        Spacer()
                        Text("\(String(format: "%.1f", systemMonitor.cpuUsage))%").font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(.cyan)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.12))
                            Capsule().fill(Color.cyan).frame(width: max(4, geo.size.width * CGFloat(systemMonitor.cpuUsage / 100.0)))
                        }
                    }.frame(height: 6)

                    HStack {
                        Text("RAM ALLOCATED").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.6))
                        Spacer()
                        Text("\(Int(systemMonitor.memoryUsageMB)) MB").font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(.yellow)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.12))
                            Capsule().fill(Color.yellow).frame(width: max(4, geo.size.width * CGFloat(systemMonitor.memoryPercentage / 100.0)))
                        }
                    }.frame(height: 6)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 2) {
                    Text("Apple Silicon arm64").font(.system(size: 10, weight: .bold)).foregroundColor(.white.opacity(0.8))
                    Text("Mach Kernel Hardware Monitor Active").font(.system(size: 9)).foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.09)).overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.12), lineWidth: 0.8)))

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "terminal.fill").foregroundColor(.green).font(.system(size: 14, weight: .bold))
                    Text("Dev Workspace").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("GIT BRANCH").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.6))
                        Spacer()
                        Text(systemMonitor.gitBranch).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(.green)
                    }

                    HStack {
                        Text("DOCKER STATUS").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.6))
                        Spacer()
                        Text(systemMonitor.dockerStatus).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(systemMonitor.dockerStatus == "Running" ? .green : .red)
                    }

                    HStack {
                        Text("ACTIVE PORTS").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.6))
                        Spacer()
                        Text("3000, 5173").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(.cyan)
                    }
                }

                Spacer()
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.09)).overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.12), lineWidth: 0.8)))

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape.fill").foregroundColor(.orange).font(.system(size: 14, weight: .bold))
                    Text("Ivors Preferences").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Always Show Compact Bar").font(.system(size: 10, weight: .semibold)).foregroundColor(.white)
                        Spacer()
                        Toggle("", isOn: $settings.alwaysShowCompactBar).toggleStyle(.switch).scaleEffect(0.7)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Blur Intensity").font(.system(size: 10, weight: .semibold)).foregroundColor(.white)
                            Spacer()
                            Text("\(Int(settings.blurIntensity * 100))%").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(settings.accentColor)
                        }
                        Slider(value: $settings.blurIntensity, in: 0.4...1.0)
                    }
                }

                Spacer()

                HStack {
                    Image(systemName: "checkmark.seal.fill").foregroundColor(.green)
                    Text("Ivors Pro Full Access").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                }
                .padding(8).background(Capsule().fill(Color.green.opacity(0.2)))
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.09)).overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.12), lineWidth: 0.8)))
        }
    }
}

struct TabIconButton: View {
    let icon: String
    let index: Int
    @Binding var selectedTab: Int

    var body: some View {
        ZStack {
            Capsule()
                .fill(selectedTab == index ? Color.white.opacity(0.25) : Color.clear)
            Image(systemName: icon)
                .font(.system(size: 11, weight: selectedTab == index ? .bold : .medium))
                .foregroundColor(selectedTab == index ? .white : .white.opacity(0.55))
        }
        .frame(width: 32, height: 24)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(AnimationController.defaultSpring) {
                selectedTab = index
            }
        }
    }
}

struct CircleActionButton: View {
    let icon: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(isActive ? 0.28 : 0.12))
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(isActive ? .orange : .white.opacity(0.85))
        }
        .frame(width: 28, height: 28)
        .contentShape(Rectangle())
        .onTapGesture {
            action()
        }
    }
}

// MARK: - Dedicated Notch File Drag & Drop Delegate
struct NotchFileDropDelegate: DropDelegate {
    @Binding var isTargeted: Bool

    func validateDrop(info: DropInfo) -> Bool {
        return info.hasItemsConforming(to: [.fileURL, .item, .data])
    }

    func dropEntered(info: DropInfo) {
        DispatchQueue.main.async {
            self.isTargeted = true
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            withAnimation(AnimationController.defaultSpring) {
                WidgetManager.shared.activeState = .maximized
            }
        }
    }

    func dropExited(info: DropInfo) {
        DispatchQueue.main.async {
            self.isTargeted = false
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        DispatchQueue.main.async {
            self.isTargeted = false
        }
        let providers = info.itemProviders(for: [.fileURL, .item, .data])
        var urls: [URL] = []
        let group = DispatchGroup()

        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url {
                    urls.append(url)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if !urls.isEmpty {
                FileStashManager.shared.addFiles(urls)
                EventBus.shared.post(.customNotification(
                    title: "\(urls.count) File(s) Stashed 📁",
                    message: urls.first?.lastPathComponent ?? "Files stashed",
                    icon: "tray.and.arrow.down.fill",
                    type: .info
                ))
            }
        }
        return true
    }
}


