import Foundation

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
}
