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
    public let name: String = "Timer & Pomodoro"
    public var priority: Int { PomodoroFocusManager.shared.isRunning ? 110 : 50 }
    public var isVisible: Bool { true }
    public var preferredCompactWidth: CGFloat { 170 }
    public var preferredExpandedSize: CGSize { CGSize(width: 340, height: 145) }

    public init() {}

    public func compactView() -> AnyView {
        let pm = PomodoroFocusManager.shared
        return AnyView(
            HStack(spacing: 6) {
                Image(systemName: "timer")
                    .foregroundColor(pm.isRunning ? .orange : .white)
                    .font(.system(size: 13, weight: .bold))
                Text(pm.formattedTime)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 8)
        )
    }

    public func expandedView() -> AnyView {
        let pm = PomodoroFocusManager.shared
        return AnyView(
            VStack(spacing: 10) {
                HStack {
                    Image(systemName: "timer")
                        .foregroundColor(.orange)
                        .font(.system(size: 15, weight: .bold))
                    Text("Focus Pomodoro")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Text(pm.currentMode.rawValue)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.orange)
                }

                Text(pm.formattedTime)
                    .font(.system(size: 34, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)

                HStack(spacing: 16) {
                    Button(action: { pm.toggleTimer() }) {
                        Text(pm.isRunning ? "Pause" : "Start")
                            .font(.system(size: 12, weight: .bold))
                            .frame(width: 76, height: 24)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(pm.isRunning ? .orange : .purple)

                    Button(action: { pm.resetTimer() }) {
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
        AnyView(Image(systemName: "timer").foregroundColor(.purple))
    }

    private func formattedTime(_ secs: Int) -> String {
        let m = secs / 60
        let s = secs % 60
        return String(format: "%02d:%02d", m, s)
    }
}
