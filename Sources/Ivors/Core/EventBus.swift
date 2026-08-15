import Foundation
import Combine
import AppKit

/// Centralized Lightweight Event Bus for event-driven system notifications
public final class EventBus {
    public static let shared = EventBus()
    
    private let subject = PassthroughSubject<SystemEvent, Never>()
    
    public var publisher: AnyPublisher<SystemEvent, Never> {
        subject.eraseToAnyPublisher()
    }
    
    private init() {}
    
    public func post(_ event: SystemEvent) {
        DispatchQueue.main.async {
            self.subject.send(event)
        }
    }
}

/// System events dispatched throughout the app
public enum SystemEvent {
    case mediaStateChanged
    case trackChanged(title: String, artist: String, artwork: NSImage?)
    case batteryStateChanged(level: Int, isCharging: Bool)
    case bluetoothDeviceConnected(name: String)
    case bluetoothDeviceDisconnected(name: String)
    case volumeChanged(level: Float)
    case brightnessChanged(level: Float)
    case customNotification(title: String, message: String, icon: String, type: NotificationType, artwork: NSImage? = nil)
    case clipboardUpdated(text: String)
    case focusModeChanged(enabled: Bool, name: String)
    case wifiStatusChanged(connected: Bool, ssid: String)
}

public enum NotificationType: String, Codable {
    case info
    case success
    case warning
    case error
}
