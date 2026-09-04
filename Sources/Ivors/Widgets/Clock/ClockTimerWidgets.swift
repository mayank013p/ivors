import SwiftUI
import Combine

public final class ClockWidget: DynamicIslandWidget, ObservableObject {
    public let id: String = "clock"
    public let name: String = "Clock"
    public let priority: Int = 60
    public var isVisible: Bool { true }
    public var preferredCompactWidth: CGFloat { 160 }
    public var preferredExpandedSize: CGSize { CGSize(width: 340, height: 130) }

    @Published public var currentTime: String = ""
    @Published public var currentDate: String = ""

    private var timer: Timer?

    public init() {
        updateTimes()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimes()
        }
    }

    private static let localTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm:ss a"
        return f
    }()

    private static let localDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f
    }()

    private func updateTimes() {
        let now = Date()
        currentTime = Self.localTimeFormatter.string(from: now)
        currentDate = Self.localDateFormatter.string(from: now)
    }

    public func compactView() -> AnyView {
        AnyView(
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 12))
                Text(currentTime)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 8)
        )
    }

    public func expandedView() -> AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.orange)
                    Text("Local Time")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(currentTime)
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    Text(currentDate)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.orange)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        )
    }

    public func minimalView() -> AnyView {
        AnyView(Image(systemName: "clock").foregroundColor(.orange))
    }
}

public final class TimerWidget: DynamicIslandWidget, ObservableObject {
    public let id: String = "timer"
    public let name: String = "Time Tools"
    public var priority: Int { PomodoroFocusManager.shared.isAnyToolRunning ? 110 : 50 }
    public var isVisible: Bool { true }
    public var preferredCompactWidth: CGFloat { 170 }
    public var preferredExpandedSize: CGSize { CGSize(width: 340, height: 145) }

    public init() {}

    public func compactView() -> AnyView {
        let pm = PomodoroFocusManager.shared
        let icon: String = {
            switch pm.selectedToolTab {
            case .pomodoro: return "timer"
            case .timer: return "hourglass"
            case .stopwatch: return "stopwatch.fill"
            }
        }()
        let timeStr: String = {
            switch pm.selectedToolTab {
            case .pomodoro: return pm.formattedTime
            case .timer: return pm.formattedCustomTimer
            case .stopwatch: return pm.formattedStopwatchTime
            }
        }()
        let isRunning: Bool = {
            switch pm.selectedToolTab {
            case .pomodoro: return pm.isRunning
            case .timer: return pm.isCustomTimerRunning
            case .stopwatch: return pm.isStopwatchRunning
            }
        }()
        let color: Color = {
            switch pm.selectedToolTab {
            case .pomodoro: return .orange
            case .timer: return .cyan
            case .stopwatch: return .green
            }
        }()

        return AnyView(
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(isRunning ? color : .white)
                    .font(.system(size: 13, weight: .bold))
                Text(timeStr)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 8)
        )
    }

    public func expandedView() -> AnyView {
        let pm = PomodoroFocusManager.shared
        let title: String = {
            switch pm.selectedToolTab {
            case .pomodoro: return "Focus Pomodoro"
            case .timer: return "Countdown Timer"
            case .stopwatch: return "Stopwatch"
            }
        }()
        let timeStr: String = {
            switch pm.selectedToolTab {
            case .pomodoro: return pm.formattedTime
            case .timer: return pm.formattedCustomTimer
            case .stopwatch: return pm.formattedStopwatchTime
            }
        }()
        let isRunning: Bool = {
            switch pm.selectedToolTab {
            case .pomodoro: return pm.isRunning
            case .timer: return pm.isCustomTimerRunning
            case .stopwatch: return pm.isStopwatchRunning
            }
        }()
        let tintColor: Color = {
            switch pm.selectedToolTab {
            case .pomodoro: return .orange
            case .timer: return .cyan
            case .stopwatch: return .green
            }
        }()

        return AnyView(
            VStack(spacing: 10) {
                HStack {
                    Image(systemName: pm.selectedToolTab.icon)
                        .foregroundColor(tintColor)
                        .font(.system(size: 15, weight: .bold))
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Text(pm.selectedToolTab == .pomodoro ? pm.currentMode.rawValue : (pm.selectedToolTab == .timer ? "\(pm.customTimerDuration / 60)m Total" : "\(pm.stopwatchLaps.count) Laps"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(tintColor)
                }

                Text(timeStr)
                    .font(.system(size: 32, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)

                HStack(spacing: 14) {
                    Button(action: {
                        switch pm.selectedToolTab {
                        case .pomodoro: pm.toggleTimer()
                        case .timer: pm.toggleCustomTimer()
                        case .stopwatch: pm.toggleStopwatch()
                        }
                    }) {
                        Text(isRunning ? "Pause" : "Start")
                            .font(.system(size: 12, weight: .bold))
                            .frame(width: 76, height: 24)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(tintColor)

                    Button(action: {
                        switch pm.selectedToolTab {
                        case .pomodoro: pm.resetTimer()
                        case .timer: pm.resetCustomTimer()
                        case .stopwatch: pm.resetStopwatch()
                        }
                    }) {
                        Text("Reset")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 66, height: 24)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        )
    }

    public func minimalView() -> AnyView {
        AnyView(Image(systemName: "timer").foregroundColor(.orange))
    }
}
