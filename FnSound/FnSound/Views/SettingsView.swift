import SwiftUI

/// SettingsView provides detailed configuration options for the app.
/// Accessible from the menu bar via Settings... or Cmd+,
struct SettingsView: View {
    @EnvironmentObject var keyMonitor: KeyMonitor
    @EnvironmentObject var soundPlayer: SoundPlayer
    @EnvironmentObject var settings: SettingsManager

    var body: some View {
        Form {
            // Trigger Settings
            Section("Trigger Settings") {
                triggerDelayControl

                Text("Shorter delay = faster response, but may trigger accidentally when using fn+key combos. Longer delay = more reliable modifier detection.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Permissions
            Section("Permissions") {
                permissionStatus
            }

            // Sound Info
            Section("Current Sound") {
                soundInfo
            }

            // About
            Section("About") {
                aboutInfo
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 400)
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
            Text("FnSound needs Input Monitoring permission to detect when you press the fn key. Click 'Grant Access' to open System Settings.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Sound Info

    @ViewBuilder
    private var soundInfo: some View {
        HStack {
            Image(systemName: "music.note")
                .font(.title2)
                .foregroundColor(.secondary)

            VStack(alignment: .leading) {
                if let soundName = soundPlayer.currentSoundName {
                    Text(soundName)
                        .fontWeight(.medium)
                    if soundPlayer.duration > 0 {
                        Text("Duration: \(soundPlayer.duration, specifier: "%.1f")s")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("No sound selected")
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if soundPlayer.hasSoundLoaded {
                Button(action: {
                    soundPlayer.play()
                }) {
                    Image(systemName: "play.fill")
                }
                .help("Test sound")
            }
        }
    }

    // MARK: - About Info

    @ViewBuilder
    private var aboutInfo: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("FnSound")
                    .fontWeight(.semibold)
                Text("Version 1.0.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }

        Text("A simple menu bar app that plays a sound when you press the fn key alone.")
            .font(.caption)
            .foregroundColor(.secondary)
    }

    // MARK: - Helpers

    private func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
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
