import Foundation
import Combine

public final class SettingsSyncManager: ObservableObject {
    public static let shared = SettingsSyncManager()

    private let projectId = "ivors-82fe1"
    private let keychain = KeychainHelper.shared
    @Published public var isSyncing: Bool = false
    @Published public var lastSyncedAt: Date? = nil

    private init() {}

    // MARK: - Push Local Settings to Cloud Firestore

    public func pushSettingsToCloud() async {
        guard AuthManager.shared.isAuthenticated,
              let uid = AuthManager.shared.currentUser?.uid,
              let idToken = keychain.readString(forKey: KeychainHelper.idTokenKey) else {
            return
        }

        await MainActor.run { self.isSyncing = true }
        defer { Task { @MainActor in self.isSyncing = false } }

        let urlString = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/users/\(uid)/settings/preferences"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let settings = SettingsManager.shared

        let firestoreFields: [String: Any] = [
            "fields": [
                "accentColorName": ["stringValue": settings.accentColorName],
                "islandScale": ["doubleValue": settings.islandScale],
                "animationSpeed": ["doubleValue": settings.animationSpeed],
                "blurIntensity": ["doubleValue": settings.blurIntensity],
                "autoHideDelay": ["doubleValue": settings.autoHideDelay],
                "enableHoverExpand": ["booleanValue": settings.enableHoverExpand],
                "duoWidgetMode": ["booleanValue": settings.duoWidgetMode],
                "updatedAt": ["stringValue": ISO8601DateFormatter().string(from: Date())]
            ]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: firestoreFields)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                await MainActor.run {
                    self.lastSyncedAt = Date()
                }
            }
        } catch {
            print("⚠️ Settings Cloud Sync push failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Pull Settings from Cloud Firestore

    public func pullSettingsFromCloud() async {
        guard AuthManager.shared.isAuthenticated,
              let uid = AuthManager.shared.currentUser?.uid,
              let idToken = keychain.readString(forKey: KeychainHelper.idTokenKey) else {
            return
        }

        await MainActor.run { self.isSyncing = true }
        defer { Task { @MainActor in self.isSyncing = false } }

        let urlString = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/users/\(uid)/settings/preferences"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let fields = json["fields"] as? [String: Any] {

                let settings = SettingsManager.shared

                await MainActor.run {
                    if let accent = (fields["accentColorName"] as? [String: Any])?["stringValue"] as? String {
                        settings.accentColorName = accent
                    }
                    if let scale = (fields["islandScale"] as? [String: Any])?["doubleValue"] as? Double {
                        settings.islandScale = scale
                    }
                    if let speed = (fields["animationSpeed"] as? [String: Any])?["doubleValue"] as? Double {
                        settings.animationSpeed = speed
                    }
                    if let blur = (fields["blurIntensity"] as? [String: Any])?["doubleValue"] as? Double {
                        settings.blurIntensity = blur
                    }
                    if let duo = (fields["duoWidgetMode"] as? [String: Any])?["booleanValue"] as? Bool {
                        settings.duoWidgetMode = duo
                    }
                    self.lastSyncedAt = Date()
                }
            }
        } catch {
            print("⚠️ Settings Cloud Sync pull failed: \(error.localizedDescription)")
        }
    }
}
