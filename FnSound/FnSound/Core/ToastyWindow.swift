import AppKit
import SwiftUI

/// A non-activating floating panel that shows the "Toasty" popup.
/// Inspired by Dan Forden's iconic MK2 easter egg - slides up from the bottom-right
/// corner without stealing focus or interrupting user input.
final class ToastyWindow: NSPanel, NSAnimationDelegate {

    private var imageView: NSImageView!
    private let baseSize: CGFloat = 300
    private let animationDuration: TimeInterval = 0.2
    private var hideWorkItem: DispatchWorkItem?
    private var currentAnimation: NSViewAnimation?

    // Store current values for hide animation
    private var currentCorner: ScreenCorner = .bottomRight
    private var currentOffsetX: Double = 0
    private var currentOffsetY: Double = 0
    private var currentScaledSize: CGFloat = 300
    private var displayDuration: TimeInterval = 1.5

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init() {
        // Position off-screen initially
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let startFrame = NSRect(
            x: screenFrame.maxX - baseSize,
            y: screenFrame.minY - baseSize,
            width: baseSize,
            height: baseSize
        )

        super.init(
            contentRect: startFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Configure as always-on-top panel (above quake-style terminals, etc.)
        self.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()) + 1)
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.ignoresMouseEvents = true  // Click-through
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        setupImageView()
    }

    private func setupImageView() {
        imageView = NSImageView(frame: NSRect(origin: .zero, size: NSSize(width: baseSize, height: baseSize)))
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true

        self.contentView = imageView
    }

    /// Show the Toasty popup with the specified image
    /// - Parameters:
    ///   - image: The image to display
    ///   - duration: How long to display before hiding (matches audio length)
    ///   - scale: Size multiplier (1.0 = 300px)
    ///   - corner: Which corner of the screen to appear in
    ///   - offsetX: Fine-tuning horizontal offset
    ///   - offsetY: Fine-tuning vertical offset
    func showToasty(with image: NSImage?, duration: TimeInterval, scale: Double = 1.0, corner: ScreenCorner = .bottomRight, offsetX: Double = 0, offsetY: Double = 0) {
        // Cancel any pending operations
        hideWorkItem?.cancel()
        currentAnimation?.stop()

        guard let screen = NSScreen.main else { return }

        // Calculate scaled size
        let scaledSize = baseSize * CGFloat(scale)

        // Set the image (use app icon as fallback)
        if let image = image {
            imageView.image = image
        } else {
            imageView.image = NSApp.applicationIconImage
        }

        // Update imageView frame for new scale
        imageView.frame = NSRect(origin: .zero, size: NSSize(width: scaledSize, height: scaledSize))

        // Store for hide animation
        self.currentCorner = corner
        self.currentOffsetX = offsetX
        self.currentOffsetY = offsetY
        self.currentScaledSize = scaledSize
        self.displayDuration = duration

        // Calculate frames based on corner
        let (startFrame, finalFrame) = calculateFrames(
            screen: screen,
            scaledSize: scaledSize,
            corner: corner,
            offsetX: offsetX,
            offsetY: offsetY
        )

        // Set initial position and show window
        self.setFrame(startFrame, display: true)
        self.orderFront(nil)

        // Use NSViewAnimation for reliable window frame animation
        let showAnimation = NSViewAnimation(viewAnimations: [
            [
                NSViewAnimation.Key.target: self,
                NSViewAnimation.Key.startFrame: NSValue(rect: startFrame),
                NSViewAnimation.Key.endFrame: NSValue(rect: finalFrame)
            ]
        ])
        showAnimation.duration = animationDuration
        showAnimation.animationCurve = .easeOut
        showAnimation.animationBlockingMode = .nonblocking
        currentAnimation = showAnimation
        showAnimation.start()

        // Schedule hide after animation completes + display duration
        let workItem = DispatchWorkItem { [weak self] in
            self?.hideToasty()
        }
        self.hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration + duration, execute: workItem)
    }

    /// Hide the Toasty popup by sliding it back out
    private func hideToasty() {
        currentAnimation?.stop()

        guard let screen = NSScreen.main else {
            self.orderOut(nil)
            return
        }

        // Calculate frames for hide animation (reverse of show)
        let (endFrame, currentFrame) = calculateFrames(
            screen: screen,
            scaledSize: currentScaledSize,
            corner: currentCorner,
            offsetX: currentOffsetX,
            offsetY: currentOffsetY
        )

        // Use NSViewAnimation for reliable window frame animation
        let hideAnimation = NSViewAnimation(viewAnimations: [
            [
                NSViewAnimation.Key.target: self,
                NSViewAnimation.Key.startFrame: NSValue(rect: currentFrame),
                NSViewAnimation.Key.endFrame: NSValue(rect: endFrame)
            ]
        ])
        hideAnimation.duration = animationDuration
        hideAnimation.animationCurve = .easeIn
        hideAnimation.animationBlockingMode = .nonblocking
        hideAnimation.delegate = self
        currentAnimation = hideAnimation
        hideAnimation.start()
    }

    /// Calculate start and final frames based on corner position
    /// - Returns: Tuple of (startFrame, finalFrame) for show animation
    private func calculateFrames(
        screen: NSScreen,
        scaledSize: CGFloat,
        corner: ScreenCorner,
        offsetX: Double,
        offsetY: Double
    ) -> (start: NSRect, final: NSRect) {
        let screenFrame = screen.frame        // Full screen including Dock/menu bar areas
        let visibleFrame = screen.visibleFrame // Excludes Dock and menu bar

        // Calculate X position based on left/right
        // Use full screen width, offset: positive = towards center
        let xPos: CGFloat
        switch corner {
        case .bottomLeft, .topLeft:
            xPos = screenFrame.minX + CGFloat(offsetX)
        case .bottomRight, .topRight:
            xPos = screenFrame.maxX - scaledSize - CGFloat(offsetX)
        }

        // Calculate Y positions based on top/bottom
        let finalY: CGFloat
        let startY: CGFloat

        switch corner {
        case .bottomLeft, .bottomRight:
            // Slide up from below screen - flush with actual screen bottom (ignores Dock)
            finalY = screenFrame.minY + CGFloat(offsetY)
            startY = screenFrame.minY - scaledSize - 10
        case .topLeft, .topRight:
            // Slide down from above screen - flush with bottom of menu bar (respects menu bar)
            finalY = visibleFrame.maxY - scaledSize - CGFloat(offsetY)
            startY = screenFrame.maxY + 10
        }

        let startFrame = NSRect(x: xPos, y: startY, width: scaledSize, height: scaledSize)
        let finalFrame = NSRect(x: xPos, y: finalY, width: scaledSize, height: scaledSize)

        return (startFrame, finalFrame)
    }

    // MARK: - NSAnimationDelegate

    func animationDidEnd(_ animation: NSAnimation) {
        // Hide window after slide-out animation completes
        if animation == currentAnimation && !self.isVisible {
            return
        }
        // Check if this was a hide animation (window should be off-screen)
        if let frame = (animation as? NSViewAnimation)?.viewAnimations.first?[NSViewAnimation.Key.endFrame] as? NSValue,
           let screen = NSScreen.main {
            let endFrame = frame.rectValue
            let screenFrame = screen.frame
            // Window is off-screen if:
            // - Top edge is at or below screen bottom (endFrame.maxY <= screenFrame.minY)
            // - Bottom edge is at or above screen top (endFrame.origin.y >= screenFrame.maxY)
            let isOffScreenBottom = endFrame.maxY <= screenFrame.minY
            let isOffScreenTop = endFrame.origin.y >= screenFrame.maxY
            if isOffScreenBottom || isOffScreenTop {
                self.orderOut(nil)
            }
        }
    }
}
