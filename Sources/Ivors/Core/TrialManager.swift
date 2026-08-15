import Foundation
import Combine

/// Manages Free Edition lifecycle & Remote Paywall configuration.
public final class TrialManager: ObservableObject {
    public static let shared = TrialManager()

    private let keychain = KeychainHelper.shared
    private let trialDurationDays: Double = 14.0
    private let trialStartKey = "ivors_trial_start_timestamp"
    private let licenseKeyStoreKey = "ivors_active_license_key"

    /// Remote Paywall Switch (Default: FALSE -> 100% FREE for all users!)
    /// Toggle to TRUE via Remote Config / GitHub config.json if you ever want to re-enable paid trials remotely.
    @Published public var isPaywallEnabled: Bool = false

    @Published public var trialStartDate: Date
    @Published public var isLicenseActivated: Bool = false
    @Published public var activatedLicenseKey: String? = nil

    private init() {
        if let storedTimestampString = keychain.readString(forKey: trialStartKey),
           let timeInterval = Double(storedTimestampString) {
            self.trialStartDate = Date(timeIntervalSince1970: timeInterval)
        } else {
            let now = Date()
            let timestampString = String(now.timeIntervalSince1970)
            _ = keychain.saveString(timestampString, forKey: trialStartKey)
            self.trialStartDate = now
        }

        if let activeKey = keychain.readString(forKey: licenseKeyStoreKey) {
            self.isLicenseActivated = true
            self.activatedLicenseKey = activeKey
        }

        // Check remote paywall configuration asynchronously
        fetchRemotePaywallStatus()
    }

    /// Fetches remote paywall status from online configuration endpoint
    public func fetchRemotePaywallStatus() {
        guard let url = URL(string: "https://raw.githubusercontent.com/mayank013p/ivors/main/config.json") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let data = data, error == nil else { return }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let enabled = json["is_paywall_enabled"] as? Bool {
                DispatchQueue.main.async {
                    self?.isPaywallEnabled = enabled
                }
            }
        }.resume()
    }

    /// Days remaining in the 14-day free trial (0 to 14)
    public var daysRemaining: Int {
        let secondsElapsed = Date().timeIntervalSince(trialStartDate)
        let daysElapsed = floor(secondsElapsed / 86400.0)
        let remaining = Int(trialDurationDays - daysElapsed)
        return max(0, remaining)
    }

    /// Progress fraction for visual progress bars (1.0 = full trial, 0.0 = expired)
    public var trialProgressFraction: Double {
        let secondsElapsed = Date().timeIntervalSince(trialStartDate)
        let totalTrialSeconds = trialDurationDays * 86400.0
        let remainingSeconds = max(0, totalTrialSeconds - secondsElapsed)
        return min(1.0, max(0.0, remainingSeconds / totalTrialSeconds))
    }

    /// Whether the 14-day trial is currently active
    public var isTrialActive: Bool {
        return daysRemaining > 0
    }

    /// Unconditionally TRUE when isPaywallEnabled == false (100% Free Edition!)
    public var hasFullAccess: Bool {
        if !isPaywallEnabled { return true }
        if isLicenseActivated { return true }
        return AuthManager.shared.isAuthenticated && isTrialActive
    }

    /// Start trial timestamp when user authenticates for the first time
    public func ensureTrialStarted() {
        if keychain.readString(forKey: trialStartKey) == nil {
            let now = Date()
            let timestampString = String(now.timeIntervalSince1970)
            _ = keychain.saveString(timestampString, forKey: trialStartKey)
            self.trialStartDate = now
        }
    }

    /// Activate a valid license key
    public func activateLicense(key: String) {
        let cleanKey = key.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        _ = keychain.saveString(cleanKey, forKey: licenseKeyStoreKey)
        self.isLicenseActivated = true
        self.activatedLicenseKey = cleanKey
    }

    /// Reset license activation (used for sign out / testing)
    public func clearLicense() {
        keychain.delete(key: licenseKeyStoreKey)
        self.isLicenseActivated = false
        self.activatedLicenseKey = nil
    }
}
