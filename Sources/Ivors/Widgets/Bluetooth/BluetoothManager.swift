import Foundation
import Combine
import IOBluetooth

public struct BluetoothDeviceInfo {
    public var name: String
    public var isConnected: Bool
    public var batteryPercentage: Int?
    public var iconName: String
}

public final class BluetoothManager: ObservableObject {
    public static let shared = BluetoothManager()

    @Published public var connectedDevices: [BluetoothDeviceInfo] = []
    private var previousConnectedNames: Set<String> = []
    private var timer: Timer?

    private init() {
        updateBluetoothDevices()
        startMonitoring()
    }

    private func startMonitoring() {
        // Optimized 10.0s background fallback polling (relying primarily on native connect notifications)
        timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.updateBluetoothDevices()
        }

        // Register native macOS Bluetooth connection observer
        IOBluetoothDevice.register(forConnectNotifications: self, selector: #selector(deviceConnectedNotification(_:device:)))
    }

    @objc private func deviceConnectedNotification(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        let name = device.nameOrAddress ?? "Bluetooth Device"
        DispatchQueue.main.async {
            EventBus.shared.post(.bluetoothDeviceConnected(name: name))
            self.updateBluetoothDevices()
        }
    }

    public func updateBluetoothDevices() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            if let devices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] {
                let connected = devices.filter { $0.isConnected() }
                let currentNames = Set(connected.compactMap { $0.nameOrAddress })

                DispatchQueue.main.async {
                    let newlyConnected = currentNames.subtracting(self.previousConnectedNames)
                    let newlyDisconnected = self.previousConnectedNames.subtracting(currentNames)
                    self.previousConnectedNames = currentNames

                    // Fire dynamic island popout for connected & disconnected Bluetooth devices!
                    for name in newlyConnected {
                        EventBus.shared.post(.bluetoothDeviceConnected(name: name))
                    }
                    for name in newlyDisconnected {
                        EventBus.shared.post(.bluetoothDeviceDisconnected(name: name))
                    }

                    if connected.isEmpty {
                        self.connectedDevices = [
                            BluetoothDeviceInfo(name: "No Devices Connected", isConnected: false, batteryPercentage: nil, iconName: "wave.3.right")
                        ]
                    } else {
                        self.connectedDevices = connected.map { dev in
                            let name = dev.nameOrAddress ?? "Bluetooth Device"
                            let lower = name.lowercased()
                            let isAudio = lower.contains("airpods") || lower.contains("headphone") || lower.contains("audio") || lower.contains("beats") || lower.contains("buds")
                            return BluetoothDeviceInfo(
                                name: name,
                                isConnected: true,
                                batteryPercentage: nil,
                                iconName: isAudio ? "airpodspro" : "wave.3.right"
                            )
                        }
                    }
                }
            }
        }
    }
}
