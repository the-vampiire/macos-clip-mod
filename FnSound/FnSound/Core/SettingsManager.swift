import Foundation
import ServiceManagement

/// Screen corner for Toasty popup positioning
enum ScreenCorner: String, CaseIterable {
    case bottomRight = "bottomRight"
    case bottomLeft = "bottomLeft"
    case topRight = "topRight"
    case topLeft = "topLeft"

    var displayName: String {
        switch self {
        case .bottomRight: return "Bottom Right"
        case .bottomLeft: return "Bottom Left"
        case .topRight: return "Top Right"
        case .topLeft: return "Top Left"
        }
    }
}

/// Menu bar icon style options
enum MenuBarIconStyle: String, CaseIterable {
    case smallText = "smallText"      // Small "LIFN" text
    case largeText = "largeText"      // Large "LIFN" text
    case letter = "letter"            // Single "L" letter
    case soundIcon = "soundIcon"      // SF Symbol speaker icon

    var displayName: String {
        switch self {
        case .smallText: return "LIFN (Small)"
        case .largeText: return "LIFN (Large)"
        case .letter: return "L Icon"
        case .soundIcon: return "Sound Icon"
        }
    }
}

/// SettingsManager handles persistence of user preferences using UserDefaults.
/// It also manages security-scoped bookmarks for accessing user-selected sound files
/// across app launches in a sandboxed environment.
final class SettingsManager: ObservableObject {
    private let defaults = UserDefaults.standard

    // MARK: - Keys

    private enum Keys {
        static let soundBookmark = "soundFileBookmark"
        static let triggerDelay = "triggerDelay"
        static let isEnabled = "isEnabled"
        static let launchAtLogin = "launchAtLogin"
        static let menuBarIconStyle = "menuBarIconStyle"
        static let randomTimerEnabled = "randomTimerEnabled"
        static let randomTimerMinInterval = "randomTimerMinInterval"
        static let randomTimerMaxInterval = "randomTimerMaxInterval"
        static let toastyEnabled = "toastyEnabled"
        static let toastyScale = "toastyScale"
        static let toastyCorner = "toastyCorner"
        static let toastyOffsetX = "toastyOffsetX"
        static let toastyOffsetY = "toastyOffsetY"
    }

    // MARK: - Published Properties

    /// Delay before triggering sound (in seconds)
    @Published var triggerDelay: TimeInterval {
        didSet {
            defaults.set(triggerDelay, forKey: Keys.triggerDelay)
        }
    }

    /// Whether monitoring is enabled
    @Published var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: Keys.isEnabled)
        }
    }

    /// Whether to launch at login
    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
            updateLaunchAtLogin(launchAtLogin)
        }
    }

    /// Menu bar icon style
    @Published var menuBarIconStyle: MenuBarIconStyle {
        didSet {
            defaults.set(menuBarIconStyle.rawValue, forKey: Keys.menuBarIconStyle)
        }
    }

    /// Whether random timer is enabled
    @Published var randomTimerEnabled: Bool {
        didSet {
            defaults.set(randomTimerEnabled, forKey: Keys.randomTimerEnabled)
        }
    }

    /// Minimum interval for random timer (in seconds)
    @Published var randomTimerMinInterval: TimeInterval {
        didSet {
            defaults.set(randomTimerMinInterval, forKey: Keys.randomTimerMinInterval)
        }
    }

    /// Maximum interval for random timer (in seconds)
    @Published var randomTimerMaxInterval: TimeInterval {
        didSet {
            defaults.set(randomTimerMaxInterval, forKey: Keys.randomTimerMaxInterval)
        }
    }

    /// Whether to show the Toasty popup when sound plays
    @Published var toastyEnabled: Bool {
        didSet {
            defaults.set(toastyEnabled, forKey: Keys.toastyEnabled)
        }
    }

    /// Scale of the Toasty popup (1.0 = 300px, range 0.5 to 3.0)
    @Published var toastyScale: Double {
        didSet {
            defaults.set(toastyScale, forKey: Keys.toastyScale)
        }
    }

    /// Corner of the screen for Toasty popup
    @Published var toastyCorner: ScreenCorner {
        didSet {
            defaults.set(toastyCorner.rawValue, forKey: Keys.toastyCorner)
        }
    }

    /// Horizontal offset for fine-tuning position (range -100...100)
    @Published var toastyOffsetX: Double {
        didSet {
            defaults.set(toastyOffsetX, forKey: Keys.toastyOffsetX)
        }
    }

    /// Vertical offset for fine-tuning position (range -100...100)
    @Published var toastyOffsetY: Double {
        didSet {
            defaults.set(toastyOffsetY, forKey: Keys.toastyOffsetY)
        }
    }

    // MARK: - Initialization

    init() {
        // Load saved settings or use defaults
        let savedDelay = defaults.double(forKey: Keys.triggerDelay)
        self.triggerDelay = savedDelay > 0 ? savedDelay : 0.4 // Default 400ms

        // Default to enabled if not set (first launch)
        if defaults.object(forKey: Keys.isEnabled) == nil {
            self.isEnabled = true
        } else {
            self.isEnabled = defaults.bool(forKey: Keys.isEnabled)
        }

        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)

        // Load menu bar icon style (default to small text)
        if let savedStyle = defaults.string(forKey: Keys.menuBarIconStyle),
           let style = MenuBarIconStyle(rawValue: savedStyle) {
            self.menuBarIconStyle = style
        } else {
            self.menuBarIconStyle = .smallText
        }

        // Random timer settings (default: disabled, 30-60 minutes)
        self.randomTimerEnabled = defaults.bool(forKey: Keys.randomTimerEnabled)

        let savedMin = defaults.double(forKey: Keys.randomTimerMinInterval)
        self.randomTimerMinInterval = savedMin >= 300 ? savedMin : 1800.0  // 30 minutes

        let savedMax = defaults.double(forKey: Keys.randomTimerMaxInterval)
        self.randomTimerMaxInterval = savedMax >= 300 ? savedMax : 3600.0  // 60 minutes

        // Toasty popup (default: enabled)
        if defaults.object(forKey: Keys.toastyEnabled) == nil {
            self.toastyEnabled = true
        } else {
            self.toastyEnabled = defaults.bool(forKey: Keys.toastyEnabled)
        }

        // Toasty scale (default: 2.0 = 600px, good size for 16" MBP)
        if defaults.object(forKey: Keys.toastyScale) == nil {
            self.toastyScale = 2.0
        } else {
            let savedScale = defaults.double(forKey: Keys.toastyScale)
            self.toastyScale = savedScale > 0 ? savedScale : 2.0
        }

        // Toasty corner (default: bottom right)
        if let savedCorner = defaults.string(forKey: Keys.toastyCorner),
           let corner = ScreenCorner(rawValue: savedCorner) {
            self.toastyCorner = corner
        } else {
            self.toastyCorner = .bottomRight
        }

        // Toasty offsets for fine-tuning (default: 0, 0 - auto-positioning handles base position)
        self.toastyOffsetX = defaults.double(forKey: Keys.toastyOffsetX)
        self.toastyOffsetY = defaults.double(forKey: Keys.toastyOffsetY)
    }

    // MARK: - Sound File Bookmark

    /// Save a security-scoped bookmark for the sound file URL.
    /// This allows the app to access the file across launches even with sandboxing.
    /// - Parameter url: The URL of the sound file
    /// - Throws: Error if bookmark creation fails
    func saveSoundBookmark(for url: URL) throws {
        let bookmarkData = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        defaults.set(bookmarkData, forKey: Keys.soundBookmark)
    }

    /// Load the saved sound file URL from its bookmark.
    /// - Returns: The URL if bookmark exists and is valid, nil otherwise
    func loadSoundURL() -> URL? {
        guard let bookmarkData = defaults.data(forKey: Keys.soundBookmark) else {
            return nil
        }

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }

        // If bookmark is stale, try to recreate it
        if isStale {
            do {
                try saveSoundBookmark(for: url)
            } catch {
                print("Failed to refresh stale bookmark: \(error)")
            }
        }

        return url
    }

    /// Get the raw bookmark data for the sound file
    func getSoundBookmarkData() -> Data? {
        return defaults.data(forKey: Keys.soundBookmark)
    }

    /// Check if a sound file bookmark is saved
    var hasSavedSound: Bool {
        return defaults.data(forKey: Keys.soundBookmark) != nil
    }

    /// Clear the saved sound file bookmark
    func clearSoundBookmark() {
        defaults.removeObject(forKey: Keys.soundBookmark)
    }

    // MARK: - Reset

    /// Reset all settings to defaults
    func resetToDefaults() {
        triggerDelay = 0.4
        isEnabled = true
        launchAtLogin = false
        clearSoundBookmark()
    }

    /// Reset Toasty position offsets to defaults
    func resetToastyOffsets() {
        toastyOffsetX = 0.0
        toastyOffsetY = 0.0
    }

    // MARK: - Launch at Login

    /// Update the system login item registration
    private func updateLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to \(enabled ? "register" : "unregister") login item: \(error)")
            }
        }
    }

    /// Sync the launchAtLogin setting with the actual system state
    func syncLaunchAtLoginState() {
        if #available(macOS 13.0, *) {
            let systemStatus = SMAppService.mainApp.status
            let isRegistered = systemStatus == .enabled
            if launchAtLogin != isRegistered {
                // Update our setting to match system state (user may have changed it in System Settings)
                launchAtLogin = isRegistered
            }
        }
    }
}
