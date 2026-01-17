import SwiftUI

/// MenuBarView provides the dropdown menu content for the menu bar icon.
/// It displays status, controls, and quick access to settings.
struct MenuBarView: View {
    @EnvironmentObject var keyMonitor: KeyMonitor
    @EnvironmentObject var soundPlayer: SoundPlayer
    @EnvironmentObject var settings: SettingsManager
    @StateObject private var brandManager = BrandManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Permission status / Enable toggle
            permissionSection

            Divider()

            // Sound selection
            soundSection

            Divider()

            // Settings and quit
            footerSection
        }
        .padding(8)
    }

    // MARK: - Permission Section

    @ViewBuilder
    private var permissionSection: some View {
        if !keyMonitor.hasPermission {
            // Show permission request button
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                    Text("Permission Required")
                        .fontWeight(.medium)
                }

                Text("\(brandManager.appDisplayName) needs Input Monitoring permission to detect the fn key.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Grant Permission...") {
                    keyMonitor.requestPermission()
                    // Check permission again after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        keyMonitor.hasPermission = keyMonitor.checkPermission()
                        if keyMonitor.hasPermission && settings.isEnabled {
                            keyMonitor.start()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        } else {
            // Show enable/disable toggle
            Toggle("Enabled", isOn: $settings.isEnabled)
                .onChange(of: settings.isEnabled) { _, enabled in
                    if enabled {
                        keyMonitor.start()
                    } else {
                        keyMonitor.stop()
                    }
                }

            // Status indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(keyMonitor.isMonitoring ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                Text(keyMonitor.isMonitoring ? "Monitoring fn key" : "Not monitoring")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Sound Section

    @ViewBuilder
    private var soundSection: some View {
        // Bundled sounds picker
        if !brandManager.bundledSounds.isEmpty {
            ForEach(brandManager.bundledSounds) { sound in
                Button(action: {
                    selectBundledSound(sound)
                }) {
                    HStack {
                        if soundPlayer.currentSoundURL == sound.url {
                            Image(systemName: "checkmark")
                                .frame(width: 16)
                        } else {
                            Color.clear
                                .frame(width: 16)
                        }
                        Text(sound.displayName)
                    }
                }
                .buttonStyle(.plain)
            }
        }

        // Error message if any
        if let error = soundPlayer.errorMessage {
            Text(error)
                .font(.caption)
                .foregroundColor(.red)
        }
    }

    // MARK: - Footer Section

    @ViewBuilder
    private var footerSection: some View {
        // Icon style picker
        Menu("Menu Bar Icon") {
            ForEach(MenuBarIconStyle.allCases, id: \.self) { style in
                Button(action: {
                    settings.menuBarIconStyle = style
                }) {
                    HStack {
                        if settings.menuBarIconStyle == style {
                            Image(systemName: "checkmark")
                        }
                        Text(style.displayName)
                    }
                }
            }
        }

        SettingsLink {
            Text("Settings...")
        }
        .keyboardShortcut(",", modifiers: .command)
        .simultaneousGesture(TapGesture().onEnded {
            NSApp.activate(ignoringOtherApps: true)
        })

        Button("Check for Updates...") {
            UpdaterManager.shared.checkForUpdates()
        }

        Divider()

        Button("Quit \(brandManager.appDisplayName)") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }

    // MARK: - Sound Selection

    private func selectBundledSound(_ sound: BundledSound) {
        do {
            try soundPlayer.loadSound(from: sound.url)
            // Clear the saved bookmark since we're using a bundled sound
            settings.clearSoundBookmark()
        } catch {
            print("Failed to load bundled sound: \(error)")
        }
    }
}

#Preview {
    MenuBarView()
        .environmentObject(KeyMonitor())
        .environmentObject(SoundPlayer())
        .environmentObject(SettingsManager())
        .frame(width: 250)
}
