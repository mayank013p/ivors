import SwiftUI

public struct SettingsView: View {
    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var widgetManager = WidgetManager.shared
    @ObservedObject var auth = AuthManager.shared
    
    // Default to Account Tab (index 3) on window open
    @State private var selectedTab: Int = 3

    public init() {}

    public var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsTab(settings: settings)
                .tabItem { Label("General", systemImage: "gear") }
                .tag(0)

            AppearanceSettingsTab(settings: settings)
                .tabItem { Label("Appearance", systemImage: "paintpalette") }
                .tag(1)

            WidgetsSettingsTab(settings: settings, widgetManager: widgetManager)
                .tabItem { Label("Widgets", systemImage: "square.grid.2x2") }
                .tag(2)

            AccountSettingsTab(auth: auth, syncManager: SettingsSyncManager.shared)
                .tabItem { Label("Account", systemImage: "envelope.badge") }
                .tag(3)

            AboutSettingsTab()
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(4)
        }
        .frame(width: 620, height: 440)
        .padding()
    }
}

struct GeneralSettingsTab: View {
    @ObservedObject var settings: SettingsManager

    var body: some View {
        Form {
            Section("Behavior") {
                Toggle("Launch at Startup", isOn: $settings.launchAtLogin)
                Toggle("Expand on Hover", isOn: $settings.enableHoverExpand)
                Toggle("Toggle Expand on Click", isOn: $settings.enableClickToggle)
                Toggle("Enable Duo Side-by-Side Widgets", isOn: $settings.duoWidgetMode)
                Toggle("Physical Notch Alignment", isOn: $settings.showNotchIntegration)
            }

            Section("Auto-Hide & Delay") {
                Slider(value: $settings.autoHideDelay, in: 1.0...10.0, step: 0.5) {
                    Text("Auto-hide delay: \(String(format: "%.1f", settings.autoHideDelay))s")
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct AppearanceSettingsTab: View {
    @ObservedObject var settings: SettingsManager

    let colorOptions = ["Orange", "Blue", "Purple", "Pink", "Green", "Red", "Yellow", "White"]

    var body: some View {
        Form {
            Section("Accent Color") {
                Picker("Theme Accent", selection: $settings.accentColorName) {
                    ForEach(colorOptions, id: \.self) { color in
                        Text(color).tag(color)
                    }
                }
            }

            Section("Glassmorphism & Scaling") {
                Slider(value: $settings.islandScale, in: 0.8...1.3, step: 0.05) {
                    Text("Island Scale: \(Int(settings.islandScale * 100))%")
                }

                Slider(value: $settings.blurIntensity, in: 0.5...1.0, step: 0.05) {
                    Text("Blur Opacity: \(Int(settings.blurIntensity * 100))%")
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct WidgetsSettingsTab: View {
    @ObservedObject var settings: SettingsManager
    @ObservedObject var widgetManager: WidgetManager

    var body: some View {
        Form {
            Section("Enable / Disable Widgets") {
                List(widgetManager.registeredWidgets, id: \.id) { widget in
                    HStack {
                        Text(widget.name)
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Text("Priority \(widget.priority)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                        Toggle("", isOn: Binding(
                            get: { settings.isWidgetEnabled(widget.id) },
                            set: { enabled in
                                settings.setWidgetEnabled(widget.id, enabled: enabled)
                                widgetManager.sortAndEvaluateActiveWidget()
                            }
                        ))
                        .labelsHidden()
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct AccountSettingsTab: View {
    @ObservedObject var auth: AuthManager
    @ObservedObject var syncManager: SettingsSyncManager
    @ObservedObject var trial = TrialManager.shared

    @State private var email: String = ""
    @State private var otpCode: String = ""
    @State private var licenseKeyInput: String = ""
    @State private var licenseMessage: String? = nil

    var body: some View {
        Form {
            if !trial.isPaywallEnabled {
                // Free Edition Banner when paywall is disabled
                Section("Ivors License & Edition") {
                    HStack(spacing: 12) {
                        Image(systemName: "gift.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(SettingsManager.shared.accentColor)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Ivors Free & Open Edition")
                                .font(.system(size: 13, weight: .bold))
                            Text("All widgets, dynamic HUDs, and feature suites are 100% free & fully unlocked.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }

                // Cloud Sync Section (Optional)
                if auth.isAuthenticated, let user = auth.currentUser {
                    Section("Ivors Cloud Sync Profile") {
                        HStack(spacing: 12) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(SettingsManager.shared.accentColor)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.email)
                                    .font(.system(size: 13, weight: .bold))
                                Text("Cloud Sync: Active")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.green)
                            }
                            Spacer()
                            Button(role: .destructive, action: {
                                auth.signOut()
                                email = ""
                                otpCode = ""
                            }) {
                                Text("Sign Out")
                                    .font(.system(size: 11))
                            }
                        }
                    }
                }
            } else {
                // Paywall Enforced Mode (When isPaywallEnabled is set to true remotely)
                if !auth.isAuthenticated && !trial.isLicenseActivated {
                    Section("Sign In / Register with 6-Digit Email OTP") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Enter your email address to receive a 6-digit verification code.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)

                            TextField("Email Address (e.g. name@domain.com)", text: $email)
                                .textFieldStyle(.roundedBorder)

                            if let error = auth.errorMessage {
                                Text(error)
                                    .font(.system(size: 11))
                                    .foregroundColor(.red)
                            }

                            Button(action: {
                                Task {
                                    do {
                                        try await auth.sendEmailOTP(email: email)
                                    } catch {}
                                }
                            }) {
                                HStack {
                                    if auth.isLoading {
                                        ProgressView().controlSize(.small)
                                    } else {
                                        Text("Send 6-Digit OTP Code")
                                            .fontWeight(.bold)
                                        Image(systemName: "paperplane.fill")
                                    }
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(SettingsManager.shared.accentColor)
                            .disabled(email.isEmpty || !email.contains("@") || auth.isLoading)
                        }
                    }
                } else {
                    Section("Subscription & License Status") {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(trial.isLicenseActivated ? "Ivors Pro License Activated" : "Trial Active (\(trial.daysRemaining) Days Left)")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct AboutSettingsTab: View {
    @State private var showUninstallConfirm: Bool = false

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 64, height: 64)
                Image(systemName: "app.dashed")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
            }

            Text("Ivors Dynamic Island")
                .font(.system(size: 18, weight: .bold))
            Text("Version 1.4.0 (Native Swift & SwiftUI)")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Text("Designed for 120Hz smooth macOS animations with ultralow idle CPU footprint (<0.8%).")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Divider()
                .padding(.vertical, 4)

            Button(role: .destructive, action: {
                showUninstallConfirm = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "trash.fill")
                    Text("Quit & Clean Uninstall Ivors...")
                }
                .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .confirmationDialog("Are you sure you want to completely uninstall Ivors?", isPresented: $showUninstallConfirm, titleVisibility: .visible) {
                Button("Uninstall & Remove Everything", role: .destructive) {
                    let task = Process()
                    task.executableURL = URL(fileURLWithPath: "/bin/bash")
                    task.arguments = ["-c", "sleep 0.5; killall Ivors 2>/dev/null; brew uninstall --cask ivors 2>/dev/null; rm -rf /Applications/Ivors.app ~/Library/Preferences/com.mayank.ivors.plist ~/Library/Application\\ Support/Ivors"]
                    try? task.run()
                    NSApplication.shared.terminate(nil)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will close Ivors and remove the application files and settings from your Mac.")
            }
        }
        .padding()
    }
}
