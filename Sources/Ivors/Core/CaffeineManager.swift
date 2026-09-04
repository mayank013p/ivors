import Foundation
import IOKit.pwr_mgt
import AppKit

public final class CaffeineManager: ObservableObject {
    public static let shared = CaffeineManager()

    @Published public var isCaffeineActive: Bool = false
    @Published public var selectedDurationMinutes: Int? = nil // nil = Indefinitely
    @Published public var remainingSeconds: Int = 0
    @Published public var preventDisplaySleep: Bool = true {
        didSet {
            if isCaffeineActive {
                reapplyAssertion()
            }
        }
    }

    private var assertionID: IOPMAssertionID = 0
    private var countdownTimer: Timer?

    private init() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWakeFromSleep),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    @objc private func handleWakeFromSleep() {
        if isCaffeineActive {
            disableCaffeine()
            enableCaffeine(durationMinutes: selectedDurationMinutes)
        }
    }

    public var formattedRemainingTime: String {
        guard isCaffeineActive else { return "Sleep Allowed" }
        let modeStr = preventDisplaySleep ? "Display On" : "System Only"
        guard selectedDurationMinutes != nil else { return "Active Indefinitely (\(modeStr))" }
        let remMins = remainingSeconds / 60
        let remSecs = remainingSeconds % 60
        return String(format: "Active: %d:%02d left (%@)", remMins, remSecs, modeStr)
    }

    public func toggleCaffeine(durationMinutes: Int? = nil) {
        if isCaffeineActive {
            disableCaffeine()
        } else {
            enableCaffeine(durationMinutes: durationMinutes)
        }
    }

    public func togglePreventDisplaySleep() {
        preventDisplaySleep.toggle()
    }

    public func enableCaffeine(durationMinutes: Int? = nil) {
        disableCaffeine()

        let assertionType = preventDisplaySleep ? 
            (kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString) : 
            (kIOPMAssertionTypeNoIdleSleep as CFString)

        let result = IOPMAssertionCreateWithName(
            assertionType,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Ivors Caffeine Keep Awake" as CFString,
            &assertionID
        )

        if result == kIOReturnSuccess {
            DispatchQueue.main.async {
                self.isCaffeineActive = true
                self.selectedDurationMinutes = durationMinutes
                if let mins = durationMinutes {
                    self.remainingSeconds = mins * 60
                    self.startCountdown()
                } else {
                    self.remainingSeconds = 0
                }

                let displayStatus = self.preventDisplaySleep ? "Screen and system awake" : "System awake (screen may sleep)"
                EventBus.shared.post(.customNotification(
                    title: "Caffeine Enabled ☕",
                    message: durationMinutes != nil ? "\(displayStatus) for \(durationMinutes!) minutes" : "\(displayStatus) indefinitely",
                    icon: "cup.and.saucer.fill",
                    type: .info
                ))
            }
        }
    }

    private func reapplyAssertion() {
        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
        }

        let assertionType = preventDisplaySleep ? 
            (kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString) : 
            (kIOPMAssertionTypeNoIdleSleep as CFString)

        _ = IOPMAssertionCreateWithName(
            assertionType,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Ivors Caffeine Keep Awake" as CFString,
            &assertionID
        )
    }

    private func startCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.remainingSeconds > 1 {
                self.remainingSeconds -= 1
            } else {
                self.disableCaffeine()
                EventBus.shared.post(.customNotification(
                    title: "Caffeine Expired ☕",
                    message: "Keep awake timer completed",
                    icon: "cup.and.saucer.fill",
                    type: .info
                ))
            }
        }
    }

    public func disableCaffeine() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
        }
        DispatchQueue.main.async {
            self.isCaffeineActive = false
            self.selectedDurationMinutes = nil
            self.remainingSeconds = 0
        }
    }
}
