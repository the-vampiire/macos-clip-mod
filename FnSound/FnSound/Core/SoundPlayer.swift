import AVFoundation
import Foundation

/// SoundPlayer handles audio playback for user-selected sound files.
/// It uses AVAudioPlayer for playback and properly handles security-scoped
/// resource access for sandboxed apps.
final class SoundPlayer: ObservableObject {
    @Published var currentSoundURL: URL?
    @Published var isPlaying = false
    @Published var errorMessage: String?

    private var audioPlayer: AVAudioPlayer?
    private var isAccessingSecurityScope = false

    // MARK: - Sound Loading

    /// Load a sound file from a URL
    /// - Parameter url: The URL of the audio file to load
    /// - Throws: Error if the file cannot be loaded
    func loadSound(from url: URL) throws {
        // Stop any currently playing sound
        stop()

        // For sandboxed apps, we need to access the security-scoped resource
        let didStartAccess = url.startAccessingSecurityScopedResource()

        do {
            // Create and prepare the audio player
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            currentSoundURL = url
            errorMessage = nil

            // Keep track of whether we started security scope access
            isAccessingSecurityScope = didStartAccess
        } catch {
            // Make sure to stop accessing if we started
            if didStartAccess {
                url.stopAccessingSecurityScopedResource()
            }
            errorMessage = "Failed to load sound: \(error.localizedDescription)"
            throw error
        }
    }

    /// Load a sound from previously saved bookmark data
    /// - Parameter bookmarkData: The security-scoped bookmark data
    /// - Returns: The resolved URL if successful
    func loadSound(fromBookmarkData bookmarkData: Data) throws -> URL? {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }

        try loadSound(from: url)
        return url
    }

    // MARK: - Playback Control

    /// Play the loaded sound from the beginning
    func play() {
        guard let player = audioPlayer else {
            errorMessage = "No sound loaded"
            return
        }

        // Reset to beginning if already playing or finished
        player.currentTime = 0
        player.play()
        isPlaying = true

        // Update isPlaying when sound finishes
        // Using a simple approach - check periodically
        DispatchQueue.main.asyncAfter(deadline: .now() + (player.duration + 0.1)) { [weak self] in
            self?.isPlaying = false
        }
    }

    /// Stop playing the current sound
    func stop() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        isPlaying = false
    }

    /// Pause the current sound
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
    }

    // MARK: - Properties

    /// The duration of the loaded sound in seconds
    var duration: TimeInterval {
        return audioPlayer?.duration ?? 0
    }

    /// Whether a sound file is currently loaded
    var hasSoundLoaded: Bool {
        return audioPlayer != nil && currentSoundURL != nil
    }

    /// The filename of the currently loaded sound
    var currentSoundName: String? {
        return currentSoundURL?.lastPathComponent
    }

    // MARK: - Cleanup

    deinit {
        stop()
        // Stop accessing security-scoped resource if we started it
        if isAccessingSecurityScope, let url = currentSoundURL {
            url.stopAccessingSecurityScopedResource()
        }
    }
}
