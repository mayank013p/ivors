import Foundation
import IOKit.ps
import Combine

public final class BatteryManager: ObservableObject {
    public static let shared = BatteryManager()

    @Published public var batteryLevel: Int = 100
    @Published public var isCharging: Bool = false
    @Published public var isLowBattery: Bool = false

    private var timer: Timer?

    private init() {
        updateBatteryState()
        startMonitoring()
    }

    public func updateBatteryState() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return
        }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }

            if let current = description[kIOPSCurrentCapacityKey] as? Int,
               let max = description[kIOPSMaxCapacityKey] as? Int {
                let percentage = Int((Double(current) / Double(max)) * 100)
                let state = description[kIOPSPowerSourceStateKey] as? String
                let isChargingState = description[kIOPSIsChargingKey] as? Bool ?? false
                let powerSourceState = (state == kIOPSACPowerValue) || isChargingState

                DispatchQueue.main.async {
                    let stateChanged = (self.isCharging != powerSourceState) || (self.batteryLevel != percentage)
                    self.batteryLevel = percentage
                    self.isCharging = powerSourceState
                    self.isLowBattery = percentage <= 20 && !powerSourceState

                    if stateChanged {
                        EventBus.shared.post(.batteryStateChanged(level: percentage, isCharging: powerSourceState))
                    }
                }
            }
        }
    }

    private func startMonitoring() {
        // Optimized 5.0s interval for low-power background execution
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateBatteryState()
        }
    }
}
