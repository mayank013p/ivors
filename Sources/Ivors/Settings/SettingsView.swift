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
            // 1. If Not Authenticated & No Pro License: Force Sign In / Register First
            if !auth.isAuthenticated && !trial.isLicenseActivated {
                Section("Step 1: Sign In or Register to Access Ivors") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.system(size: 28))
                                .foregroundColor(SettingsManager.shared.accentColor)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Account Required")
                                    .font(.system(size: 13, weight: .bold))
                                Text("Sign in or create a free account via Email OTP to unlock your 14-Day Free Trial.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                if !auth.otpSent {
                    Section(header: Text("Sign In / Register with 6-Digit Email OTP")) {
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
                    Section(header: Text("Enter Verification Code")) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "envelope.badge.shield.half.filled")
                                    .foregroundColor(SettingsManager.shared.accentColor)
                                Text("Code sent to **\(auth.pendingEmail ?? email)**")
                                    .font(.system(size: 12))
                            }

                            TextField("6-Digit OTP Code (e.g. 849201)", text: $otpCode)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 14, weight: .bold, design: .monospaced))

                            if let error = auth.errorMessage {
                                Text(error)
                                    .font(.system(size: 11))
                                    .foregroundColor(.red)
                            }

                            HStack {
                                Button(action: {
                                    Task {
                                        do {
                                            try await auth.verifyOTP(code: otpCode)
                                            await syncManager.pullSettingsFromCloud()
                                        } catch {}
                                    }
                                }) {
                                    HStack {
                                        if auth.isLoading {
                                            ProgressView().controlSize(.small)
                                        } else {
                                            Text("Verify Code & Start Trial")
                                                .fontWeight(.bold)
                                            Image(systemName: "checkmark.seal.fill")
                                        }
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(SettingsManager.shared.accentColor)
                                .disabled(otpCode.count < 6 || auth.isLoading)

                                Spacer()

                                Button(action: {
                                    auth.otpSent = false
                                    otpCode = ""
                                }) {
                                    Text("Change Email")
                                        .font(.system(size: 11))
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(.blue)
                            }
                        }
                    }
                }
            } else {
                // 2. Authenticated OR Pro License: Display Trial Status & Profile
                Section("Subscription & Trial Status") {
                    if trial.isLicenseActivated {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Ivors Pro License Activated")
                                    .font(.system(size: 13, weight: .bold))
                                if let key = trial.activatedLicenseKey {
                                    Text("Key: \(key)")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Button("Deactivate") {
                                trial.clearLicense()
                            }
                            .buttonStyle(.borderless)
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                        }
                        .padding(.vertical, 2)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("14-Day Free Trial")
                                    .font(.system(size: 13, weight: .bold))
                                Spacer()
                                Text("\(trial.daysRemaining) Days Remaining")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(trial.daysRemaining > 3 ? .green : .orange)
                            }

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 6)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(trial.daysRemaining > 3 ? Color.green : Color.orange)
                                        .frame(width: geo.size.width * trial.trialProgressFraction, height: 6)
                                }
                            }
                            .frame(height: 6)
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Profile Section
                if auth.isAuthenticated, let user = auth.currentUser {
                    Section("Ivors Account Profile") {
                        HStack(spacing: 12) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 36))
                                .foregroundColor(SettingsManager.shared.accentColor)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.email)
                                    .font(.system(size: 14, weight: .bold))
                                
                                if trial.isLicenseActivated {
                                    Text("Tier: Pro (Lifetime)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.green)
                                } else if trial.isTrialActive {
                                    Text("Tier: Free Trial (\(trial.daysRemaining) Days Left)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.orange)
                                } else {
                                    Text("Tier: Trial Expired")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.red)
                                }
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
            }

            // 3. Purchase Pro License & Key Activation
            if !trial.isLicenseActivated {
                Section("Activate License Key") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Image(systemName: "creditcard.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.orange)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Purchase License Key")
                                    .font(.system(size: 13, weight: .bold))
                                Text("Pay securely via Razorpay webpage to receive your license key instantly.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button(action: {
                                if let url = URL(string: SettingsManager.shared.razorpayPaymentPageURL) {
                                    NSWorkspace.shared.open(url)
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Text("Buy on Razorpay")
                                    Image(systemName: "arrow.up.right")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                        }
                        .padding(.vertical, 2)

                        Divider()

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Already completed payment? Enter your License Key below:")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)

                            HStack {
                                TextField("IVORS-PRO-XXXX-YYYY-ZZZZ", text: $licenseKeyInput)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 12, design: .monospaced))

                                Button("Activate Key") {
                                    Task {
                                        do {
                                            try await auth.activateLicenseKey(key: licenseKeyInput)
                                            licenseMessage = "License Activated Successfully!"
                                            licenseKeyInput = ""
                                        } catch {
                                            licenseMessage = error.localizedDescription
                                        }
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(SettingsManager.shared.accentColor)
                                .disabled(licenseKeyInput.count < 10)
                            }

                            if let msg = licenseMessage {
                                Text(msg)
                                    .font(.system(size: 11))
                                    .foregroundColor(msg.contains("Successfully") ? .green : .red)
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct AboutSettingsTab: View {
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
            Text("Version 1.0.0 (Native Swift & SwiftUI)")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Text("Designed for 120Hz smooth macOS animations with ultralow idle CPU footprint (<0.8%).")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding()
    }
}
