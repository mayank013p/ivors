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

        var selectedDescription: [String: Any]? = nil
        for source in sources {
            if let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] {
                if let type = description[kIOPSTypeKey] as? String, type == kIOPSInternalBatteryType {
                    selectedDescription = description
                    break
                }
                if selectedDescription == nil {
                    selectedDescription = description
                }
            }
        }

        guard let description = selectedDescription else { return }

        if let current = description[kIOPSCurrentCapacityKey] as? Int,
           let max = description[kIOPSMaxCapacityKey] as? Int, max > 0 {
            let percentage = Int((Double(current) / Double(max)) * 100)
            let state = description[kIOPSPowerSourceStateKey] as? String
            let isChargingState = description[kIOPSIsChargingKey] as? Bool ?? false
            let powerSourceState = (state == kIOPSACPowerValue) || isChargingState

            DispatchQueue.main.async {
                let chargingChanged = (self.isCharging != powerSourceState)
                let levelChanged = (self.batteryLevel != percentage)

                self.batteryLevel = percentage
                self.isCharging = powerSourceState
                self.isLowBattery = percentage <= 20 && !powerSourceState

                if chargingChanged || levelChanged {
                    EventBus.shared.post(.batteryStateChanged(level: percentage, isCharging: powerSourceState))
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
