import Foundation

/// Represents a bundled sound that comes with the app
struct BundledSound: Identifiable, Hashable {
    let id: String
    let filename: String
    let displayName: String
    let url: URL
    let isDefault: Bool
}

/// Brand configuration loaded from brand.json
struct BrandConfig: Codable {
    let brandId: String
    let appName: String
    let bundleIdentifier: String
    let displayName: String
    let version: String
    let sounds: [String: SoundConfig]?
    let menuBarIcon: String?
    let defaultSettings: DefaultSettings?

    struct SoundConfig: Codable {
        let filename: String
        let displayName: String
        let isDefault: Bool?
    }

    struct DefaultSettings: Codable {
        let triggerDelay: Double?
        let blockSystemBehavior: Bool?
    }
}

/// Manages brand-specific configuration and bundled resources
final class BrandManager: ObservableObject {
    static let shared = BrandManager()

    @Published private(set) var brandConfig: BrandConfig?
    @Published private(set) var bundledSounds: [BundledSound] = []
    @Published private(set) var isGenericBuild: Bool = true

    /// The display name for the app (brand name or "FnSound")
    var appDisplayName: String {
        brandConfig?.displayName ?? "FnSound"
    }

    /// The default sound to use (first bundled sound marked as default, or first bundled sound)
    var defaultSound: BundledSound? {
        bundledSounds.first { $0.isDefault } ?? bundledSounds.first
    }

    private init() {
        loadBrandConfig()
        loadBundledSounds()
    }

    /// Load brand configuration from brand.json in the app bundle
    private func loadBrandConfig() {
        guard let configURL = Bundle.main.url(forResource: "brand", withExtension: "json"),
              let data = try? Data(contentsOf: configURL),
              let config = try? JSONDecoder().decode(BrandConfig.self, from: data) else {
            // No brand.json means this is a generic build
            isGenericBuild = true
            return
        }

        brandConfig = config
        isGenericBuild = false
    }

    /// Load bundled sounds from the Sounds directory in the app bundle
    private func loadBundledSounds() {
        var sounds: [BundledSound] = []

        // Check for Sounds directory in bundle
        if let soundsURL = Bundle.main.url(forResource: "Sounds", withExtension: nil),
           let contents = try? FileManager.default.contentsOfDirectory(
               at: soundsURL,
               includingPropertiesForKeys: nil,
               options: [.skipsHiddenFiles]
           ) {
            // Load sounds based on brand config if available
            if let soundConfigs = brandConfig?.sounds {
                for (id, config) in soundConfigs {
                    if let soundURL = contents.first(where: { $0.lastPathComponent == config.filename }) {
                        sounds.append(BundledSound(
                            id: id,
                            filename: config.filename,
                            displayName: config.displayName,
                            url: soundURL,
                            isDefault: config.isDefault ?? false
                        ))
                    }
                }
            } else {
                // No brand config, just load all audio files
                let audioExtensions = ["mp3", "wav", "aiff", "m4a", "caf", "aac"]
                for fileURL in contents {
                    let ext = fileURL.pathExtension.lowercased()
                    if audioExtensions.contains(ext) {
                        let filename = fileURL.lastPathComponent
                        let displayName = fileURL.deletingPathExtension().lastPathComponent
                            .replacingOccurrences(of: "_", with: " ")
                            .replacingOccurrences(of: ".", with: " ")
                        sounds.append(BundledSound(
                            id: filename,
                            filename: filename,
                            displayName: displayName,
                            url: fileURL,
                            isDefault: sounds.isEmpty // First sound is default
                        ))
                    }
                }
            }
        }

        // Sort so default comes first
        bundledSounds = sounds.sorted { $0.isDefault && !$1.isDefault }
    }

    /// Check if a custom menu bar icon is available
    var hasCustomMenuBarIcon: Bool {
        Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png") != nil
    }

    /// Get the custom menu bar icon image name if available
    var menuBarIconName: String? {
        if hasCustomMenuBarIcon {
            return "MenuBarIcon"
        }
        return nil
    }
}
