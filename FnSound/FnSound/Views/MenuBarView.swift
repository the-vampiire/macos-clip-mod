import SwiftUI
import UniformTypeIdentifiers

/// MenuBarView provides the dropdown menu content for the menu bar icon.
/// It displays status, controls, and quick access to settings.
struct MenuBarView: View {
    @EnvironmentObject var keyMonitor: KeyMonitor
    @EnvironmentObject var soundPlayer: SoundPlayer
    @EnvironmentObject var settings: SettingsManager

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
        .onAppear {
            setupApp()
        }
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

                Text("FnSound needs Input Monitoring permission to detect the fn key.")
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
        // Current sound display
        if let soundName = soundPlayer.currentSoundName {
            HStack {
                Image(systemName: "music.note")
                    .foregroundColor(.secondary)
                Text(soundName)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        } else {
            HStack {
                Image(systemName: "music.note")
                    .foregroundColor(.secondary)
                Text("No sound selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }

        // Sound control buttons
        HStack(spacing: 8) {
            Button("Choose Sound...") {
                selectSoundFile()
            }

            Button(action: {
                soundPlayer.play()
            }) {
                Image(systemName: "play.fill")
            }
            .disabled(!soundPlayer.hasSoundLoaded)
            .help("Test sound")
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
        SettingsLink {
            Text("Settings...")
        }
        .keyboardShortcut(",", modifiers: .command)

        Button("Quit FnSound") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }

    // MARK: - Setup

    private func setupApp() {
        // Check permission status
        keyMonitor.hasPermission = keyMonitor.checkPermission()

        // Load saved sound file
        if let savedURL = settings.loadSoundURL() {
            do {
                try soundPlayer.loadSound(from: savedURL)
            } catch {
                print("Failed to load saved sound: \(error)")
            }
        }

        // Connect the trigger callback
        keyMonitor.onTrigger = { [weak soundPlayer] in
            soundPlayer?.play()
        }

        // Sync trigger delay from settings
        keyMonitor.triggerDelay = settings.triggerDelay

        // Start monitoring if enabled and permitted
        if settings.isEnabled && keyMonitor.hasPermission {
            keyMonitor.start()
        }
    }

    // MARK: - File Selection

    private func selectSoundFile() {
        let panel = NSOpenPanel()
        panel.title = "Choose a Sound File"
        panel.message = "Select an audio file to play when fn key is pressed"
        panel.prompt = "Select"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        // Allow common audio formats
        panel.allowedContentTypes = [
            .audio,
            .mp3,
            .wav,
            .aiff,
            UTType(filenameExtension: "m4a") ?? .audio,
            UTType(filenameExtension: "caf") ?? .audio,
            UTType(filenameExtension: "aac") ?? .audio
        ]

        if panel.runModal() == .OK, let url = panel.url {
            do {
                // Load the sound
                try soundPlayer.loadSound(from: url)

                // Save bookmark for persistence
                try settings.saveSoundBookmark(for: url)
            } catch {
                print("Failed to load sound: \(error)")
            }
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
