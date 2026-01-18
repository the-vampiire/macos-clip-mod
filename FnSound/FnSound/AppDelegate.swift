import AppKit
import SwiftUI

// MARK: - Window Foregrounding

/// Manages bringing windows to foreground for LSUIElement (menu bar only) apps.
/// Menu bar apps don't normally bring windows to front, so we need to temporarily
/// switch to regular activation policy when showing windows like Settings or Updates.
final class WindowForegrounding {
    static let shared = WindowForegrounding()

    /// Windows that should be foregrounded when they appear
    /// Matches by identifier prefix to catch variants (e.g., Sparkle windows)
    private let managedWindowPrefixes = [
        "com_apple_SwiftUI_Settings_window",  // SwiftUI Settings window
        "SUUpdate",                            // Sparkle update windows
        "SPU",                                 // Sparkle windows (newer naming)
    ]

    /// Track which windows we've already activated (by identifier)
    private var activatedWindows = Set<String>()

    /// Count of managed windows currently open
    private var openManagedWindowCount = 0

    private var updateObserver: NSObjectProtocol?
    private var closeObserver: NSObjectProtocol?

    private init() {}

    /// Start observing for windows that need foregrounding
    func startObserving() {
        // Watch for window updates to catch windows appearing
        updateObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didUpdateNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleWindowUpdate(notification)
        }

        // Watch for windows closing to restore accessory mode
        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleWindowClose(notification)
        }
    }

    private func handleWindowUpdate(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window.isVisible,
              let identifier = window.identifier?.rawValue,
              !activatedWindows.contains(identifier),
              isManagedWindow(identifier) else {
            return
        }

        // New managed window appeared - bring to front
        activatedWindows.insert(identifier)
        openManagedWindowCount += 1

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    private func handleWindowClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              let identifier = window.identifier?.rawValue,
              activatedWindows.contains(identifier) else {
            return
        }

        activatedWindows.remove(identifier)
        openManagedWindowCount -= 1

        // Only restore accessory mode when all managed windows are closed
        if openManagedWindowCount <= 0 {
            openManagedWindowCount = 0
            NSApp.setActivationPolicy(.accessory)
        }
    }

    private func isManagedWindow(_ identifier: String) -> Bool {
        managedWindowPrefixes.contains { identifier.hasPrefix($0) }
    }
}

// MARK: - App Delegate

/// AppDelegate handles app lifecycle events for proper initialization at launch.
/// This ensures key monitoring starts immediately, not when the menu is first opened.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var keyMonitor: KeyMonitor?
    private var soundPlayer: SoundPlayer?
    private var settings: SettingsManager?

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
        WindowForegrounding.shared.startObserving()
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
}
