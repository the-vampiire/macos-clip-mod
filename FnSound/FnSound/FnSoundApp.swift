import SwiftUI
import AppKit

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
        MenuBarExtra {
            MenuBarView()
                .environmentObject(keyMonitor)
                .environmentObject(soundPlayer)
                .environmentObject(settings)
        } label: {
            menuBarIcon
        }

        // Settings window (accessible from menu bar)
        Settings {
            SettingsView()
                .environmentObject(keyMonitor)
                .environmentObject(soundPlayer)
                .environmentObject(settings)
        }
    }

    /// Menu bar icon - based on user's selected style
    @ViewBuilder
    private var menuBarIcon: some View {
        switch settings.menuBarIconStyle {
        case .smallText:
            if let icon = loadIcon(named: "menubar_small") {
                Image(nsImage: icon)
            } else {
                Image(systemName: "speaker.wave.2.fill")
            }
        case .largeText:
            if let icon = loadIcon(named: "menubar_large") {
                Image(nsImage: icon)
            } else {
                Image(systemName: "speaker.wave.2.fill")
            }
        case .letter:
            if let icon = loadIcon(named: "menubar_letter") {
                Image(nsImage: icon)
            } else {
                Image(systemName: "speaker.wave.2.fill")
            }
        case .soundIcon:
            Image(systemName: "speaker.wave.2.fill")
        }
    }

    /// Load menu bar icon from app bundle Resources
    private func loadIcon(named name: String) -> NSImage? {
        guard let iconURL = Bundle.main.url(forResource: name, withExtension: "png"),
              let image = NSImage(contentsOf: iconURL) else {
            return nil
        }
        image.isTemplate = true
        return image
    }

    init() {
        // Initial setup is done in MenuBarView.onAppear to ensure
        // environment objects are properly available
    }
}
