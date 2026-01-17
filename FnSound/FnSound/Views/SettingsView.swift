import SwiftUI

/// SettingsView provides detailed configuration options for the app.
/// Accessible from the menu bar via Settings... or Cmd+,
struct SettingsView: View {
    @EnvironmentObject var keyMonitor: KeyMonitor
    @EnvironmentObject var soundPlayer: SoundPlayer
    @EnvironmentObject var settings: SettingsManager
    @StateObject private var brandManager = BrandManager.shared

    var body: some View {
        Form {
            // General Settings
            Section("General") {
                Toggle("Launch at Login", isOn: $settings.launchAtLogin)

                Text("Automatically start \(brandManager.appDisplayName) when you log in.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Permissions (Input Monitoring + System fn key)
            Section("Permissions") {
                permissionStatus

                Divider()
                    .padding(.vertical, 4)

                // System fn key behavior
                VStack(alignment: .leading, spacing: 8) {
                    Text("Disable System fn Key Popup")
                        .fontWeight(.medium)

                    Text("To prevent the input source switcher from appearing when you press fn, open Keyboard Settings and set \"Press 🌐 key to\" to \"Do Nothing\" or \"Start Dictation\".")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button("Open Keyboard Settings") {
                        openKeyboardSettings()
                    }
                }
            }

            // Trigger Settings
            Section("Trigger Settings") {
                triggerDelayControl

                Text("Shorter delay = faster response, but may trigger accidentally when using fn+key combos. Longer delay = more reliable modifier detection.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Random Timer
            Section("Random Timer") {
                Toggle("Enable random triggers", isOn: $settings.randomTimerEnabled)
                    .onChange(of: settings.randomTimerEnabled) { _, enabled in
                        if enabled {
                            ToastyManager.shared.updateTimerSettings(
                                minInterval: settings.randomTimerMinInterval,
                                maxInterval: settings.randomTimerMaxInterval
                            )
                            ToastyManager.shared.startRandomTimer()
                        } else {
                            ToastyManager.shared.stopRandomTimer()
                        }
                    }

                if settings.randomTimerEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Min interval:")
                            Spacer()
                            Text("\(Int(settings.randomTimerMinInterval / 60))m")
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $settings.randomTimerMinInterval, in: 300...3600, step: 300)
                            .onChange(of: settings.randomTimerMinInterval) { _, newValue in
                                // Ensure max is at least min
                                if settings.randomTimerMaxInterval < newValue {
                                    settings.randomTimerMaxInterval = newValue
                                }
                                ToastyManager.shared.updateTimerSettings(
                                    minInterval: newValue,
                                    maxInterval: settings.randomTimerMaxInterval
                                )
                            }

                        HStack {
                            Text("Max interval:")
                            Spacer()
                            Text("\(Int(settings.randomTimerMaxInterval / 60))m")
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $settings.randomTimerMaxInterval, in: 300...7200, step: 300)
                            .onChange(of: settings.randomTimerMaxInterval) { _, newValue in
                                // Ensure max is at least min
                                let actualMax = max(newValue, settings.randomTimerMinInterval)
                                if actualMax != newValue {
                                    settings.randomTimerMaxInterval = actualMax
                                }
                                ToastyManager.shared.updateTimerSettings(
                                    minInterval: settings.randomTimerMinInterval,
                                    maxInterval: actualMax
                                )
                            }
                    }
                }

                Text("When enabled, the sound will play randomly between the min and max intervals. For the people.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Toasty Popup
            Section("Toasty!") {
                Toggle("Show popup when sound plays", isOn: $settings.toastyEnabled)
                    .onChange(of: settings.toastyEnabled) { _, enabled in
                        ToastyManager.shared.toastyEnabled = enabled
                    }

                if settings.toastyEnabled {
                    VStack(alignment: .leading, spacing: 12) {
                        // Scale slider
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Size:")
                                Spacer()
                                Text("\(Int(settings.toastyScale * 100))% (\(Int(300 * settings.toastyScale))px)")
                                    .monospacedDigit()
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $settings.toastyScale, in: 0.5...3.0, step: 0.25)
                                .onChange(of: settings.toastyScale) { _, newValue in
                                    ToastyManager.shared.toastyScale = newValue
                                }
                        }

                        // X offset slider
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("X offset (from right):")
                                Spacer()
                                Text("\(Int(settings.toastyOffsetX))px")
                                    .monospacedDigit()
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $settings.toastyOffsetX, in: -200...500, step: 10)
                                .onChange(of: settings.toastyOffsetX) { _, newValue in
                                    ToastyManager.shared.toastyOffsetX = newValue
                                }
                        }

                        // Y offset slider
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Y offset (from bottom):")
                                Spacer()
                                Text("\(Int(settings.toastyOffsetY))px")
                                    .monospacedDigit()
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $settings.toastyOffsetY, in: -200...500, step: 10)
                                .onChange(of: settings.toastyOffsetY) { _, newValue in
                                    ToastyManager.shared.toastyOffsetY = newValue
                                }
                        }

                        Text("Adjust size and position. X: positive = further left. Y: positive = higher up.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Text("When enabled, a small image pops up from the corner of your screen when the sound plays. Inspired by Dan Forden's iconic MK2 easter egg.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button("Test Toasty") {
                    ToastyManager.shared.showToasty()
                }
            }

            // About
            Section("About") {
                aboutInfo
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 700)
    }

    // MARK: - Trigger Delay Control

    @ViewBuilder
    private var triggerDelayControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Delay before trigger:")
                Spacer()
                Text("\(settings.triggerDelay, specifier: "%.1f")s")
                    .monospacedDigit()
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .trailing)
            }

            Slider(value: $settings.triggerDelay, in: 0.1...1.0, step: 0.1) {
                Text("Trigger Delay")
            } minimumValueLabel: {
                Text("0.1s")
                    .font(.caption2)
            } maximumValueLabel: {
                Text("1.0s")
                    .font(.caption2)
            }
            .onChange(of: settings.triggerDelay) { _, newValue in
                keyMonitor.triggerDelay = newValue
            }
        }
    }

    // MARK: - Permission Status

    @ViewBuilder
    private var permissionStatus: some View {
        HStack {
            Image(systemName: keyMonitor.hasPermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(keyMonitor.hasPermission ? .green : .red)
                .font(.title3)

            VStack(alignment: .leading) {
                Text("Input Monitoring")
                    .fontWeight(.medium)
                Text(keyMonitor.hasPermission ? "Permission granted" : "Permission required")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if !keyMonitor.hasPermission {
                Button("Grant Access") {
                    keyMonitor.requestPermission()
                }
            } else {
                Button("Open System Settings") {
                    openPrivacySettings()
                }
                .buttonStyle(.link)
            }
        }

        if !keyMonitor.hasPermission {
            Text("\(brandManager.appDisplayName) needs Input Monitoring permission to detect when you press the fn key. Click 'Grant Access' to open System Settings.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - About Info

    @ViewBuilder
    private var aboutInfo: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(brandManager.appDisplayName)
                    .fontWeight(.semibold)
                Text("Version \(brandManager.brandConfig?.version ?? "1.0.0")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }

        Text("A life-changing menu bar app that reminds you to LIFN.")
            .font(.caption)
            .foregroundColor(.secondary)

        Button("Check for Updates...") {
            UpdaterManager.shared.checkForUpdates()
        }
    }

    // MARK: - Helpers

    private func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openKeyboardSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(KeyMonitor())
        .environmentObject(SoundPlayer())
        .environmentObject(SettingsManager())
}
