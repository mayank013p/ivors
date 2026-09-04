import Foundation
import Combine
import AppKit
import UserNotifications

public enum FocusMode: String, CaseIterable {
    case work = "Deep Focus"
    case shortBreak = "Short Break"
    case longBreak = "Long Break"
    case powerSprint = "Power Sprint"

    public var defaultDuration: Int {
        switch self {
        case .work: return 25 * 60
        case .shortBreak: return 5 * 60
        case .longBreak: return 15 * 60
        case .powerSprint: return 45 * 60
        }
    }

    public var durationMinutes: Int {
        defaultDuration / 60
    }


    public var icon: String {
        switch self {
        case .work: return "brain.head.profile"
        case .shortBreak: return "cup.and.saucer.fill"
        case .longBreak: return "bed.double.fill"
        case .powerSprint: return "bolt.fill"
        }
    }
}

public enum TimeToolTab: String, CaseIterable {
    case pomodoro = "Pomodoro"
    case timer = "Timer"
    case stopwatch = "Stopwatch"

    public var icon: String {
        switch self {
        case .pomodoro: return "timer"
        case .timer: return "hourglass"
        case .stopwatch: return "stopwatch.fill"
        }
    }
}

public struct StopwatchLap: Identifiable, Equatable {
    public let id = UUID()
    public let lapNumber: Int
    public let lapTime: Double
    public let totalTime: Double

    public var formattedLapTime: String {
        let mins = Int(lapTime) / 60
        let secs = Int(lapTime) % 60
        let centis = Int((lapTime.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", mins, secs, centis)
    }

    public var formattedTotalTime: String {
        let mins = Int(totalTime) / 60
        let secs = Int(totalTime) % 60
        let centis = Int((totalTime.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", mins, secs, centis)
    }
}

public final class PomodoroFocusManager: ObservableObject {
    public static let shared = PomodoroFocusManager()

    // MARK: - Selected Sub-Tool
    @Published public var selectedToolTab: TimeToolTab = .pomodoro

    // MARK: - Pomodoro Focus State
    @Published public var currentMode: FocusMode = .work
    @Published public var timeRemaining: Int = 25 * 60
    @Published public var isRunning: Bool = false
    @Published public var completedSessionsCount: Int = 4
    @Published public var dailyGoalSessions: Int = 4
    private var timer: Timer?

    // MARK: - Countdown Timer State
    @Published public var customTimerDuration: Int = 10 * 60
    @Published public var customTimerRemaining: Int = 10 * 60
    @Published public var isCustomTimerRunning: Bool = false
    private var customTimer: Timer?

    // MARK: - Stopwatch State
    @Published public var stopwatchElapsed: Double = 0.0
    @Published public var isStopwatchRunning: Bool = false
    @Published public var stopwatchLaps: [StopwatchLap] = []
    private var stopwatchTimer: Timer?
    private var stopwatchStartTime: Date?
    private var stopwatchAccumulatedBeforeStart: Double = 0.0
    private var lastLapTimestamp: Double = 0.0

    private init() {
        if Bundle.main.bundleIdentifier != nil {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
    }

    // MARK: - Pomodoro Computed Properties
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

    // MARK: - Custom Timer Computed Properties
    public var formattedCustomTimer: String {
        let minutes = customTimerRemaining / 60
        let seconds = customTimerRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    public var customTimerProgress: Double {
        guard customTimerDuration > 0 else { return 0 }
        return 1.0 - (Double(customTimerRemaining) / Double(customTimerDuration))
    }

    // MARK: - Stopwatch Computed Properties
    public var formattedStopwatchTime: String {
        let totalSecs = Int(stopwatchElapsed)
        let mins = totalSecs / 60
        let secs = totalSecs % 60
        let centis = Int((stopwatchElapsed.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", mins, secs, centis)
    }

    public var isAnyToolRunning: Bool {
        return isRunning || isCustomTimerRunning || isStopwatchRunning
    }

    // MARK: - Pomodoro Actions
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

    // MARK: - Custom Timer Actions
    public func setCustomTimerDuration(_ seconds: Int) {
        pauseCustomTimer()
        customTimerDuration = seconds
        customTimerRemaining = seconds
        WidgetManager.shared.sortAndEvaluateActiveWidget()
    }

    public func addCustomTimerMinutes(_ mins: Int) {
        let addedSeconds = mins * 60
        customTimerDuration += addedSeconds
        customTimerRemaining += addedSeconds
        WidgetManager.shared.sortAndEvaluateActiveWidget()
    }

    public func toggleCustomTimer() {
        if isCustomTimerRunning {
            pauseCustomTimer()
        } else {
            startCustomTimer()
        }
    }

    public func startCustomTimer() {
        isCustomTimerRunning = true
        customTimer?.invalidate()
        customTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.customTimerRemaining > 0 {
                self.customTimerRemaining -= 1
            } else {
                self.customTimerCompleted()
            }
        }
        WidgetManager.shared.sortAndEvaluateActiveWidget()
    }

    public func pauseCustomTimer() {
        isCustomTimerRunning = false
        customTimer?.invalidate()
        WidgetManager.shared.sortAndEvaluateActiveWidget()
    }

    public func resetCustomTimer() {
        pauseCustomTimer()
        customTimerRemaining = customTimerDuration
        WidgetManager.shared.sortAndEvaluateActiveWidget()
    }

    private func customTimerCompleted() {
        pauseCustomTimer()
        NSSound.beep()
        EventBus.shared.post(.customNotification(
            title: "Timer Finished! ⏰",
            message: "Your \(customTimerDuration / 60)m countdown timer has ended.",
            icon: "hourglass.bottomhalf.filled",
            type: .info
        ))
    }

    // MARK: - Stopwatch Actions
    public func toggleStopwatch() {
        if isStopwatchRunning {
            pauseStopwatch()
        } else {
            startStopwatch()
        }
    }

    public func startStopwatch() {
        guard !isStopwatchRunning else { return }
        isStopwatchRunning = true
        stopwatchStartTime = Date()
        stopwatchAccumulatedBeforeStart = stopwatchElapsed
        stopwatchTimer?.invalidate()
        stopwatchTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.stopwatchStartTime else { return }
            let currentSession = Date().timeIntervalSince(start)
            self.stopwatchElapsed = self.stopwatchAccumulatedBeforeStart + currentSession
        }
        WidgetManager.shared.sortAndEvaluateActiveWidget()
    }

    public func pauseStopwatch() {
        isStopwatchRunning = false
        stopwatchTimer?.invalidate()
        stopwatchTimer = nil
        if let start = stopwatchStartTime {
            stopwatchElapsed = stopwatchAccumulatedBeforeStart + Date().timeIntervalSince(start)
        }
        stopwatchStartTime = nil
        WidgetManager.shared.sortAndEvaluateActiveWidget()
    }

    public func resetStopwatch() {
        pauseStopwatch()
        stopwatchElapsed = 0.0
        stopwatchAccumulatedBeforeStart = 0.0
        lastLapTimestamp = 0.0
        stopwatchLaps.removeAll()
        WidgetManager.shared.sortAndEvaluateActiveWidget()
    }

    public func recordLap() {
        guard isStopwatchRunning || stopwatchElapsed > 0 else { return }
        let currentTotal = stopwatchElapsed
        let lapDuration = max(0.01, currentTotal - lastLapTimestamp)
        lastLapTimestamp = currentTotal
        let lap = StopwatchLap(
            lapNumber: stopwatchLaps.count + 1,
            lapTime: lapDuration,
            totalTime: currentTotal
        )
        stopwatchLaps.insert(lap, at: 0)
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }
}

