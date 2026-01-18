import AppKit
import Combine

/// ToastyManager coordinates the Toasty popup, random timer, and sound playback.
/// It handles showing the iconic corner popup and triggering sounds at random intervals.
final class ToastyManager: ObservableObject {

    static let shared = ToastyManager()

    @Published var isRandomTimerRunning = false

    private var toastyWindow: ToastyWindow?
    private var randomTimer: DispatchSourceTimer?
    private var toastyImage: NSImage?

    /// Track screen lock and screensaver state
    private var isScreenLocked = false
    private var isScreensaverActive = false

    /// Callback to play the sound - returns the audio duration
    var onTrigger: (() -> TimeInterval)?

    /// Whether to show the Toasty popup
    var toastyEnabled: Bool = true

    /// Scale of the popup (1.0 = 300px base size, default 2.0 = 600px)
    var toastyScale: Double = 2.0

    /// Horizontal offset from right edge
    var toastyOffsetX: Double = 0.0

    /// Vertical offset from bottom edge (negative = below screen edge for slide-up effect)
    var toastyOffsetY: Double = -50.0

    /// Fallback duration if audio duration unknown
    private let fallbackDuration: TimeInterval = 1.5

    /// Random timer interval range
    var minInterval: TimeInterval = 30.0
    var maxInterval: TimeInterval = 120.0

    private init() {
        // Load toasty image from bundle if available, otherwise use app icon
        loadToastyImage()
        // Start observing screen lock and screensaver state
        observeScreenState()
    }

    // MARK: - Screen State Observation

    private func observeScreenState() {
        let dnc = DistributedNotificationCenter.default()

        // Screen lock notifications
        dnc.addObserver(
            self,
            selector: #selector(screenDidLock),
            name: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil
        )
        dnc.addObserver(
            self,
            selector: #selector(screenDidUnlock),
            name: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )

        // Screensaver notifications
        dnc.addObserver(
            self,
            selector: #selector(screensaverDidStart),
            name: NSNotification.Name("com.apple.screensaver.didstart"),
            object: nil
        )
        dnc.addObserver(
            self,
            selector: #selector(screensaverDidStop),
            name: NSNotification.Name("com.apple.screensaver.didstop"),
            object: nil
        )
    }

    @objc private func screenDidLock() {
        isScreenLocked = true
    }

    @objc private func screenDidUnlock() {
        isScreenLocked = false
    }

    @objc private func screensaverDidStart() {
        isScreensaverActive = true
    }

    @objc private func screensaverDidStop() {
        isScreensaverActive = false
    }

    /// Check if screen is currently active (not locked, no screensaver)
    private var isScreenActive: Bool {
        return !isScreenLocked && !isScreensaverActive
    }

    private func loadToastyImage() {
        // Try to load custom toasty image from bundle
        if let imageURL = Bundle.main.url(forResource: "ToastyImage", withExtension: "png"),
           let image = NSImage(contentsOf: imageURL) {
            toastyImage = image
        } else if let imageURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
                  let image = NSImage(contentsOf: imageURL) {
            toastyImage = image
        } else {
            // Fall back to app icon
            toastyImage = NSApp.applicationIconImage
        }
    }

    // MARK: - Toasty Popup

    /// Trigger the Toasty effect - show popup and play sound
    /// Skips triggering if screen is locked or screensaver is active
    func trigger() {
        // Don't trigger when screen is locked or screensaver is active
        guard isScreenActive else { return }

        // Play sound and get duration
        let duration = onTrigger?() ?? fallbackDuration

        // Show popup if enabled
        if toastyEnabled {
            showToasty(duration: duration)
        }
    }

    /// Show just the Toasty popup (without triggering sound)
    /// - Parameter duration: How long to show the popup (defaults to fallback)
    func showToasty(duration: TimeInterval? = nil) {
        let displayDuration = duration ?? fallbackDuration
        DispatchQueue.main.async {
            if self.toastyWindow == nil {
                self.toastyWindow = ToastyWindow()
            }
            self.toastyWindow?.showToasty(
                with: self.toastyImage,
                duration: displayDuration,
                scale: self.toastyScale,
                offsetX: self.toastyOffsetX,
                offsetY: self.toastyOffsetY
            )
        }
    }

    // MARK: - Random Timer

    /// Start the random timer
    func startRandomTimer() {
        stopRandomTimer()

        isRandomTimerRunning = true
        scheduleNextRandomTrigger()
    }

    /// Stop the random timer
    func stopRandomTimer() {
        randomTimer?.cancel()
        randomTimer = nil
        isRandomTimerRunning = false
    }

    /// Schedule the next random trigger
    private func scheduleNextRandomTrigger() {
        guard isRandomTimerRunning else { return }

        // Calculate random interval between min and max
        let interval = TimeInterval.random(in: minInterval...maxInterval)

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + interval)
        timer.setEventHandler { [weak self] in
            guard let self = self, self.isRandomTimerRunning else { return }

            // Trigger the effect
            self.trigger()

            // Schedule next one
            self.scheduleNextRandomTrigger()
        }
        timer.resume()
        randomTimer = timer
    }

    /// Update timer settings and restart if running
    func updateTimerSettings(minInterval: TimeInterval, maxInterval: TimeInterval) {
        self.minInterval = minInterval
        self.maxInterval = max(maxInterval, minInterval) // Ensure max >= min

        // Restart timer if running to pick up new settings
        if isRandomTimerRunning {
            startRandomTimer()
        }
    }

    // MARK: - Cleanup

    func cleanup() {
        stopRandomTimer()
        toastyWindow?.orderOut(nil)
        toastyWindow = nil
    }
}
