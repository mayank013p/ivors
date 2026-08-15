import Foundation
import Combine
import AppKit
import UserNotifications

public enum FocusMode: String {
    case work = "Deep Focus"
    case shortBreak = "Short Break"
    case longBreak = "Long Break"

    public var defaultDuration: Int {
        switch self {
        case .work: return 25 * 60
        case .shortBreak: return 5 * 60
        case .longBreak: return 15 * 60
        }
    }
}

public final class PomodoroFocusManager: ObservableObject {
    public static let shared = PomodoroFocusManager()

    @Published public var currentMode: FocusMode = .work
    @Published public var timeRemaining: Int = 25 * 60
    @Published public var isRunning: Bool = false
    @Published public var completedSessionsCount: Int = 4

    private var timer: Timer?

    private init() {
        if Bundle.main.bundleIdentifier != nil {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
    }

    public var formattedTime: String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    public var progress: Double {
        let total = currentMode.defaultDuration
        guard total > 0 else { return 0 }
        return 1.0 - (Double(timeRemaining) / Double(total))
    }

    public func setMode(_ mode: FocusMode) {
        pauseTimer()
        currentMode = mode
        timeRemaining = mode.defaultDuration
        WidgetManager.shared.sortAndEvaluateActiveWidget()
    }

    public func toggleTimer() {
        if isRunning {
            pauseTimer()
        } else {
            startTimer()
        }
    }

    public func startTimer() {
        isRunning = true
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
            } else {
                self.timerCompleted()
            }
        }
        WidgetManager.shared.sortAndEvaluateActiveWidget()
    }

    public func pauseTimer() {
        isRunning = false
        timer?.invalidate()
        WidgetManager.shared.sortAndEvaluateActiveWidget()
    }

    public func resetTimer() {
        pauseTimer()
        timeRemaining = currentMode.defaultDuration
        WidgetManager.shared.sortAndEvaluateActiveWidget()
    }

    private func timerCompleted() {
        pauseTimer()
        NSSound.beep()

        let titleStr = currentMode == .work ? "Focus Session Complete! 🎉" : "Break Complete! ⚡"
        let msgStr = currentMode == .work ? "Great work! Time for a 5-minute break." : "Ready to get back to deep focus?"

        if Bundle.main.bundleIdentifier != nil {
            let content = UNMutableNotificationContent()
            content.title = titleStr
            content.body = msgStr
            content.sound = .default
            let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
        }

        if currentMode == .work {
            completedSessionsCount += 1
            EventBus.shared.post(.customNotification(
                title: titleStr,
                message: msgStr,
                icon: "timer",
                type: .info
            ))
            setMode(.shortBreak)
        } else {
            EventBus.shared.post(.customNotification(
                title: titleStr,
                message: msgStr,
                icon: "sparkles",
                type: .info
            ))
            setMode(.work)
        }
    }
}
