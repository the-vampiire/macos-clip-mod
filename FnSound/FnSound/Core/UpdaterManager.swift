import Foundation
import Sparkle
import os.log

/// Manages app updates via Sparkle framework.
/// Handles checking for updates and user-initiated update checks.
final class UpdaterManager: NSObject, ObservableObject {

    static let shared = UpdaterManager()

    static let logger = Logger(subsystem: "com.lifn.fnsound", category: "Updater")

    private var updaterController: SPUStandardUpdaterController!
    private var updaterDelegate: UpdaterDelegate!

    var updater: SPUUpdater {
        updaterController.updater
    }

    private override init() {
        super.init()

        Self.logger.info("Initializing Sparkle updater...")

        // Create delegate first
        updaterDelegate = UpdaterDelegate()

        // Initialize Sparkle with our delegate
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: updaterDelegate,
            userDriverDelegate: nil
        )

        Self.logger.info("Sparkle updater initialized")
    }

    /// Check for updates (user-initiated)
    func checkForUpdates() {
        Self.logger.info("User initiated update check")
        updater.checkForUpdates()
    }

    /// Whether the updater can check for updates
    var canCheckForUpdates: Bool {
        updater.canCheckForUpdates
    }
}

/// Delegate to capture Sparkle events and errors for logging
final class UpdaterDelegate: NSObject, SPUUpdaterDelegate {

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        UpdaterManager.logger.error("Sparkle aborted with error: \(error.localizedDescription)")
        UpdaterManager.logger.error("Error details: \(String(describing: error))")
        if let nsError = error as NSError? {
            UpdaterManager.logger.error("Error domain: \(nsError.domain), code: \(nsError.code)")
            UpdaterManager.logger.error("Error userInfo: \(String(describing: nsError.userInfo))")
        }
    }

    func updater(_ updater: SPUUpdater, didFinishLoading appcast: SUAppcast) {
        UpdaterManager.logger.info("Loaded appcast with \(appcast.items.count) items")
        for item in appcast.items {
            UpdaterManager.logger.info("Appcast item: version=\(item.versionString ?? "nil"), displayVersion=\(item.displayVersionString ?? "nil")")
        }
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        UpdaterManager.logger.info("Found valid update: \(item.displayVersionString ?? "unknown") (build \(item.versionString ?? "unknown"))")
        UpdaterManager.logger.info("Download URL: \(item.fileURL?.absoluteString ?? "nil")")
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        UpdaterManager.logger.info("No update found: \(error.localizedDescription)")
    }

    func updater(_ updater: SPUUpdater, willDownloadUpdate item: SUAppcastItem, with request: NSMutableURLRequest) {
        UpdaterManager.logger.info("Will download update from: \(request.url?.absoluteString ?? "nil")")
    }

    func updater(_ updater: SPUUpdater, didDownloadUpdate item: SUAppcastItem) {
        UpdaterManager.logger.info("Downloaded update: \(item.displayVersionString ?? "unknown")")
    }

    func updater(_ updater: SPUUpdater, failedToDownloadUpdate item: SUAppcastItem, error: Error) {
        UpdaterManager.logger.error("Failed to download update: \(error.localizedDescription)")
        UpdaterManager.logger.error("Download error details: \(String(describing: error))")
        if let nsError = error as NSError? {
            UpdaterManager.logger.error("Download error domain: \(nsError.domain), code: \(nsError.code)")
            UpdaterManager.logger.error("Download error userInfo: \(String(describing: nsError.userInfo))")
        }
    }

    func updater(_ updater: SPUUpdater, didExtractUpdate item: SUAppcastItem) {
        UpdaterManager.logger.info("Extracted update: \(item.displayVersionString ?? "unknown")")
    }

    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        UpdaterManager.logger.info("Will install update: \(item.displayVersionString ?? "unknown")")
    }

    func updater(_ updater: SPUUpdater, didCancelInstallUpdateOnQuit item: SUAppcastItem) {
        UpdaterManager.logger.info("User cancelled install on quit")
    }

    func updater(_ updater: SPUUpdater, willInstallUpdateOnQuit item: SUAppcastItem, immediateInstallationBlock immediateInstallHandler: @escaping () -> Void) {
        UpdaterManager.logger.info("Will install update on quit: \(item.displayVersionString ?? "unknown")")
    }
}
