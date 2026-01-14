import Cocoa
import CoreGraphics

/// KeyMonitor handles detection of the fn key being pressed alone (not as a modifier).
/// It uses CGEventTap to monitor keyboard events and implements a timer-based approach
/// to distinguish "fn alone" from "fn + other key" combinations.
///
/// State Machine:
/// - IDLE: Waiting for fn key press
/// - WAITING: fn pressed, timer running
/// - TRIGGER: Timer fired or fn released while timer valid -> play sound
/// - CANCEL: Another key pressed while fn is down -> don't trigger
final class KeyMonitor: ObservableObject {
    @Published var isMonitoring = false
    @Published var hasPermission = false

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var fnPressedTime: Date?
    private var triggerTimer: DispatchSourceTimer?
    private var shouldTriggerOnRelease = false

    /// Callback invoked when fn key is pressed alone
    var onTrigger: (() -> Void)?

    /// Delay in seconds before considering fn key as "pressed alone"
    /// If another key is pressed within this time, the trigger is cancelled
    var triggerDelay: TimeInterval = 0.4

    /// When true, blocks the system's default fn key behavior (e.g., input source switcher)
    /// Changing this requires restarting the monitor
    var blockSystemBehavior: Bool = true

    // MARK: - Permission Handling

    /// Check if the app has Input Monitoring permission
    func checkPermission() -> Bool {
        return CGPreflightListenEventAccess()
    }

    /// Request Input Monitoring permission from the user
    /// This will open System Settings if permission hasn't been granted
    func requestPermission() {
        CGRequestListenEventAccess()
    }

    // MARK: - Event Tap Management

    /// Start monitoring keyboard events
    func start() {
        guard eventTap == nil else { return }

        // Check permission first
        guard checkPermission() else {
            hasPermission = false
            requestPermission()
            return
        }

        hasPermission = true

        // Event mask for flagsChanged (modifier keys) and keyDown events
        let eventMask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue) |
                                      (1 << CGEventType.keyDown.rawValue)

        // Pass self as userInfo to access from C callback
        let userInfo = Unmanaged.passRetained(self).toOpaque()

        // Create the event tap
        // Use .defaultTap when blocking system behavior (allows us to consume events)
        // Use .listenOnly when not blocking (just observe events)
        let tapOptions: CGEventTapOptions = blockSystemBehavior ? .defaultTap : .listenOnly

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: tapOptions,
            eventsOfInterest: eventMask,
            callback: KeyMonitor.eventCallback,
            userInfo: userInfo
        ) else {
            print("Failed to create event tap. Make sure Input Monitoring permission is granted.")
            Unmanaged<KeyMonitor>.fromOpaque(userInfo).release()
            hasPermission = false
            return
        }

        eventTap = tap

        // Create run loop source and add to current run loop
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)

        // Enable the tap
        CGEvent.tapEnable(tap: tap, enable: true)

        isMonitoring = true
    }

    /// Stop monitoring keyboard events
    func stop() {
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            // Release the retained self reference
            // Note: We need to be careful here as the callback might still be in use
            eventTap = nil
        }

        cancelTriggerTimer()
        fnPressedTime = nil
        shouldTriggerOnRelease = false
        isMonitoring = false
    }

    deinit {
        stop()
    }

    // MARK: - Event Callback

    /// C function pointer callback for CGEventTap
    private static let eventCallback: CGEventTapCallBack = { proxy, type, event, userInfo in
        guard let userInfo = userInfo else {
            return Unmanaged.passUnretained(event)
        }

        let monitor = Unmanaged<KeyMonitor>.fromOpaque(userInfo).takeUnretainedValue()

        // Handle tap being disabled (system can disable it if callback takes too long)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = monitor.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        // Process the event on main thread for thread safety with @Published properties
        let eventType = type
        let flags = event.flags

        // Check if this is an fn key event that we should block
        var shouldBlockEvent = false
        if monitor.blockSystemBehavior && eventType == .flagsChanged {
            // Check if fn key state changed by looking at the flags
            // We block flagsChanged events that involve the fn key
            let fnIsInFlags = flags.contains(.maskSecondaryFn)
            let fnWasPressed = monitor.fnPressedTime != nil

            // Block if fn is being pressed or released
            if fnIsInFlags || fnWasPressed {
                shouldBlockEvent = true
            }
        }

        DispatchQueue.main.async {
            if eventType == .flagsChanged {
                monitor.handleFlagsChanged(flags)
            } else if eventType == .keyDown {
                monitor.handleKeyDown()
            }
        }

        // Return nil to consume/block the event, or the event to let it pass through
        if shouldBlockEvent {
            return nil
        }
        return Unmanaged.passUnretained(event)
    }

    // MARK: - Event Handling

    /// Handle modifier key state changes (including fn key)
    private func handleFlagsChanged(_ flags: CGEventFlags) {
        let fnPressed = flags.contains(.maskSecondaryFn)

        if fnPressed && fnPressedTime == nil {
            // fn key just pressed - start the timer
            fnPressedTime = Date()
            shouldTriggerOnRelease = true
            startTriggerTimer()
        } else if !fnPressed && fnPressedTime != nil {
            // fn key released
            if shouldTriggerOnRelease {
                // Timer hasn't been cancelled by another key press, trigger the sound
                trigger()
            }
            // Reset state
            fnPressedTime = nil
            shouldTriggerOnRelease = false
            cancelTriggerTimer()
        }
    }

    /// Handle regular key presses (cancels fn-alone trigger)
    private func handleKeyDown() {
        // Any key pressed while fn is down means fn is being used as a modifier
        // Cancel the trigger
        if fnPressedTime != nil {
            shouldTriggerOnRelease = false
            cancelTriggerTimer()
        }
    }

    // MARK: - Timer Management

    /// Start the trigger delay timer
    private func startTriggerTimer() {
        cancelTriggerTimer()

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + triggerDelay)
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            // Timer fired while fn is still held - this is also a valid trigger case
            // But we'll wait for release to avoid double triggers
            // The shouldTriggerOnRelease flag is still true, so release will trigger
        }
        timer.resume()
        triggerTimer = timer
    }

    /// Cancel the trigger delay timer
    private func cancelTriggerTimer() {
        triggerTimer?.cancel()
        triggerTimer = nil
    }

    // MARK: - Trigger

    /// Trigger the sound callback
    private func trigger() {
        onTrigger?()
    }
}
