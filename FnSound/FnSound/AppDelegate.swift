import AppKit
import SwiftUI

/// AppDelegate handles app lifecycle events for proper initialization at launch.
/// This ensures key monitoring starts immediately, not when the menu is first opened.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var keyMonitor: KeyMonitor?
    private var soundPlayer: SoundPlayer?
    private var settings: SettingsManager?
    private var settingsWindowObserver: NSObjectProtocol?

    /// Configure the delegate with the app's state objects
    func configure(
        keyMonitor: KeyMonitor,
        soundPlayer: SoundPlayer,
        settings: SettingsManager
    ) {
        self.keyMonitor = keyMonitor
        self.soundPlayer = soundPlayer
        self.settings = settings
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupApp()
        observeSettingsWindow()
    }

    /// Initialize the app's core functionality
    /// This runs at app launch, not when the menu is first opened
    private func setupApp() {
        guard let keyMonitor = keyMonitor,
              let soundPlayer = soundPlayer,
              let settings = settings else {
            return
        }

        // Check permission status
        keyMonitor.hasPermission = keyMonitor.checkPermission()

        // Load saved sound file, or default bundled sound
        var soundLoaded = false
        if let savedURL = settings.loadSoundURL() {
            do {
                try soundPlayer.loadSound(from: savedURL)
                soundLoaded = true
            } catch {
                print("Failed to load saved sound: \(error)")
            }
        }

        // If no saved sound, try to load default bundled sound
        let brandManager = BrandManager.shared
        if !soundLoaded, let defaultSound = brandManager.defaultSound {
            do {
                try soundPlayer.loadSound(from: defaultSound.url)
            } catch {
                print("Failed to load default bundled sound: \(error)")
            }
        }

        // Setup ToastyManager
        let toastyManager = ToastyManager.shared
        toastyManager.toastyEnabled = settings.toastyEnabled
        toastyManager.toastyScale = settings.toastyScale
        toastyManager.toastyCorner = settings.toastyCorner
        toastyManager.toastyOffsetX = settings.toastyOffsetX
        toastyManager.toastyOffsetY = settings.toastyOffsetY
        toastyManager.onTrigger = { [weak soundPlayer] in
            soundPlayer?.play()
            return soundPlayer?.duration ?? 1.5
        }

        // Connect fn key trigger to ToastyManager (shows popup + plays sound)
        keyMonitor.onTrigger = { [weak soundPlayer] in
            if settings.toastyEnabled {
                toastyManager.trigger()
            } else {
                soundPlayer?.play()
            }
        }

        // Sync settings to key monitor
        keyMonitor.triggerDelay = settings.triggerDelay

        // Start random timer if enabled
        if settings.randomTimerEnabled {
            toastyManager.updateTimerSettings(
                minInterval: settings.randomTimerMinInterval,
                maxInterval: settings.randomTimerMaxInterval
            )
            toastyManager.startRandomTimer()
        }

        // Start monitoring if enabled and permitted
        if settings.isEnabled && keyMonitor.hasPermission {
            keyMonitor.start()
        }

        // Sync launch at login state with system (in case user changed it in System Settings)
        settings.syncLaunchAtLoginState()
    }

    /// Observe when the settings window becomes visible and bring it to front
    /// This fixes the issue where settings window opens behind other windows in menu bar apps
    private func observeSettingsWindow() {
        settingsWindowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let window = notification.object as? NSWindow,
                  window.identifier?.rawValue == "com_apple_SwiftUI_Settings_window" else { return }
            NSApp.activate(ignoringOtherApps: true)
            window.orderFrontRegardless()
        }
    }
}
