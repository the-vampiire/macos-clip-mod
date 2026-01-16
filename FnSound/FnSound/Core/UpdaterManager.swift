import Foundation
import Sparkle

/// Manages app updates via Sparkle framework.
/// Handles checking for updates and user-initiated update checks.
final class UpdaterManager: ObservableObject {

    static let shared = UpdaterManager()

    private let updaterController: SPUStandardUpdaterController

    var updater: SPUUpdater {
        updaterController.updater
    }

    private init() {
        // Initialize Sparkle with standard user interface
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    /// Check for updates (user-initiated)
    func checkForUpdates() {
        updater.checkForUpdates()
    }

    /// Whether the updater can check for updates
    var canCheckForUpdates: Bool {
        updater.canCheckForUpdates
    }
}
