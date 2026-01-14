import SwiftUI

/// FnSound - A macOS menu bar app that plays a sound when the fn key is pressed alone.
///
/// The app runs as a menu bar only application (no dock icon) and monitors keyboard
/// events to detect when the fn key is pressed without any other key combination.
@main
struct FnSoundApp: App {
    @StateObject private var keyMonitor = KeyMonitor()
    @StateObject private var soundPlayer = SoundPlayer()
    @StateObject private var settings = SettingsManager()

    var body: some Scene {
        // Menu bar icon and dropdown menu
        MenuBarExtra("FnSound", systemImage: "speaker.wave.2.fill") {
            MenuBarView()
                .environmentObject(keyMonitor)
                .environmentObject(soundPlayer)
                .environmentObject(settings)
        }

        // Settings window (accessible from menu bar)
        Settings {
            SettingsView()
                .environmentObject(keyMonitor)
                .environmentObject(soundPlayer)
                .environmentObject(settings)
        }
    }

    init() {
        // Initial setup is done in MenuBarView.onAppear to ensure
        // environment objects are properly available
    }
}
