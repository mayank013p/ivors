import Foundation
import CoreGraphics
import CoreAudio
import SwiftUI
import Combine

typealias DisplayServicesGetLinearBrightnessFunc = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32

public enum HUDType: Equatable {
    case volume(Float)
    case brightness(Float)
}

public final class VolumeBrightnessHUDManager: ObservableObject {
    public static let shared = VolumeBrightnessHUDManager()

    @Published public var currentHUD: HUDType? = nil
    @Published public var isHUDActive: Bool = false
    @Published public var liveSystemVolume: Float = 0.8
    @Published public var outputDeviceName: String = "MacBook Speakers"

    private var previousVolume: Float = -1
    private var previousBrightness: Float = -1
    private var timer: Timer?
    private var dismissTimer: Timer?
    private var displayServicesFn: DisplayServicesGetLinearBrightnessFunc?

    private init() {
        setupDisplayServices()
        startMonitoring()
    }

    private func setupDisplayServices() {
        if let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY) {
            if let sym = dlsym(handle, "DisplayServicesGetLinearBrightness") {
                displayServicesFn = unsafeBitCast(sym, to: DisplayServicesGetLinearBrightnessFunc.self)
            }
        }
    }

    public func startMonitoring() {
        previousVolume = getSystemVolume()
        previousBrightness = getDisplayBrightness()
        updateLiveSystemState()

        setupAudioListener()

        // Fast 0.25s polling timer for instant volume & brightness sync across all Bluetooth & system devices
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.checkVolumeChange()
            self?.checkBrightnessChange()
        }
    }

    public func updateLiveSystemState() {
        let vol = getSystemVolume()
        let device = getOutputDeviceName()
        DispatchQueue.main.async {
            self.liveSystemVolume = vol
            self.outputDeviceName = device
        }
    }

    public func getOutputDeviceName() -> String {
        var defaultOutputDeviceID = AudioDeviceID(0)
        var defaultOutputDeviceIDSize = UInt32(MemoryLayout.size(ofValue: defaultOutputDeviceID))
        var defaultOutputDevicePropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &defaultOutputDevicePropertyAddress, 0, nil, &defaultOutputDeviceIDSize, &defaultOutputDeviceID)
        guard status == noErr else { return "MacBook Speakers" }

        var deviceNameCF: Unmanaged<CFString>?
        var deviceNameSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let nameStatus = AudioObjectGetPropertyData(defaultOutputDeviceID, &nameAddress, 0, nil, &deviceNameSize, &deviceNameCF)
        if nameStatus == noErr, let cfStr = deviceNameCF?.takeRetainedValue() {
            let name = cfStr as String
            return name.isEmpty ? "MacBook Speakers" : name
        }
        return "MacBook Speakers"
    }

    private func setupAudioListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, DispatchQueue.main) { [weak self] _, _ in
            self?.attachDeviceVolumeListener()
            self?.checkVolumeChange()
        }

        attachDeviceVolumeListener()
    }

    private func attachDeviceVolumeListener() {
        var defaultOutputDeviceID = AudioDeviceID(0)
        var defaultOutputDeviceIDSize = UInt32(MemoryLayout.size(ofValue: defaultOutputDeviceID))
        var defaultOutputDevicePropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &defaultOutputDevicePropertyAddress, 0, nil, &defaultOutputDeviceIDSize, &defaultOutputDeviceID)
        guard status == noErr else { return }

        var volumeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectAddPropertyListenerBlock(defaultOutputDeviceID, &volumeAddress, DispatchQueue.main) { [weak self] _, _ in
            self?.checkVolumeChange()
        }
        
        volumeAddress.mElement = 1
        AudioObjectAddPropertyListenerBlock(defaultOutputDeviceID, &volumeAddress, DispatchQueue.main) { [weak self] _, _ in
            self?.checkVolumeChange()
        }
    }

    private func checkVolumeChange() {
        updateLiveSystemState()
        let currentVol = getSystemVolume()
        if previousVolume >= 0 {
            let diff = abs(currentVol - previousVolume)
            if diff >= 0.008 {
                previousVolume = currentVol
                if !WidgetManager.shared.isTemporaryPopupActive {
                    triggerHUD(.volume(currentVol))
                }
            }
        } else {
            previousVolume = currentVol
        }
    }

    private func checkBrightnessChange() {
        if WidgetManager.shared.isTemporaryPopupActive { return }
        let currentBright = getDisplayBrightness()
        if previousBrightness >= 0 && abs(currentBright - previousBrightness) >= 0.035 {
            previousBrightness = currentBright
            triggerHUD(.brightness(currentBright))
        } else {
            previousBrightness = currentBright
        }
    }

    public func triggerHUD(_ hud: HUDType) {
        DispatchQueue.main.async {
            self.currentHUD = hud
            self.isHUDActive = true

            let wasHidden = WidgetManager.shared.activeState == .minimal || WidgetManager.shared.activeState == .hidden
            if wasHidden {
                withAnimation(AnimationController.defaultSpring) {
                    WidgetManager.shared.activeState = .compact
                }
            }

            self.dismissTimer?.invalidate()
            self.dismissTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
                withAnimation(AnimationController.defaultSpring) {
                    self?.isHUDActive = false
                    self?.currentHUD = nil
                    if wasHidden {
                        WidgetManager.shared.sortAndEvaluateActiveWidget()
                    }
                }
            }
        }
    }

    public var currentSystemVolume: Float {
        getSystemVolume()
    }

    public func setSystemVolume(_ volume: Float) {
        var defaultOutputDeviceID = AudioDeviceID(0)
        var defaultOutputDeviceIDSize = UInt32(MemoryLayout.size(ofValue: defaultOutputDeviceID))
        var defaultOutputDevicePropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &defaultOutputDevicePropertyAddress, 0, nil, &defaultOutputDeviceIDSize, &defaultOutputDeviceID)
        guard status == noErr else { return }

        var newVolume = max(0.0, min(1.0, volume))
        let volumeSize = UInt32(MemoryLayout.size(ofValue: newVolume))

        // Set Master (0), Left (1), and Right (2) channels so both earphones update simultaneously
        let channelsToSet: [UInt32] = [
            kAudioObjectPropertyElementMain, // 0 - Master
            1,                               // 1 - Left Channel
            2                                // 2 - Right Channel
        ]

        for channel in channelsToSet {
            var volumePropertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: channel
            )
            _ = AudioObjectSetPropertyData(defaultOutputDeviceID, &volumePropertyAddress, 0, nil, volumeSize, &newVolume)
        }

        previousVolume = newVolume
        DispatchQueue.main.async {
            self.liveSystemVolume = newVolume
        }
    }

    public func getSystemVolume() -> Float {
        var defaultOutputDeviceID = AudioDeviceID(0)
        var defaultOutputDeviceIDSize = UInt32(MemoryLayout.size(ofValue: defaultOutputDeviceID))
        var defaultOutputDevicePropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &defaultOutputDevicePropertyAddress, 0, nil, &defaultOutputDeviceIDSize, &defaultOutputDeviceID)
        guard status == noErr else { return previousVolume >= 0 ? previousVolume : 0.5 }

        var volume: Float32 = 0.0
        var volumeSize = UInt32(MemoryLayout.size(ofValue: volume))

        // 1. Try Master Channel (0)
        var volumePropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        let res = AudioObjectGetPropertyData(defaultOutputDeviceID, &volumePropertyAddress, 0, nil, &volumeSize, &volume)
        if res == noErr { return volume }

        // 2. Try Left Channel (1) and Right Channel (2) and return average
        var leftVol: Float32 = 0.0
        var rightVol: Float32 = 0.0

        volumePropertyAddress.mElement = 1
        let leftStatus = AudioObjectGetPropertyData(defaultOutputDeviceID, &volumePropertyAddress, 0, nil, &volumeSize, &leftVol)

        volumePropertyAddress.mElement = 2
        let rightStatus = AudioObjectGetPropertyData(defaultOutputDeviceID, &volumePropertyAddress, 0, nil, &volumeSize, &rightVol)

        if leftStatus == noErr && rightStatus == noErr {
            return (leftVol + rightVol) / 2.0
        } else if leftStatus == noErr {
            return leftVol
        } else if rightStatus == noErr {
            return rightVol
        }

        return previousVolume >= 0 ? previousVolume : 0.5
    }

    private func getDisplayBrightness() -> Float {
        var brightness: Float = 0.75
        if let fn = displayServicesFn {
            _ = fn(CGMainDisplayID(), &brightness)
        }
        return brightness
    }
}
