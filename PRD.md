# FnSound: macOS Key Sound Effect App — Product Requirements Document

## Overview

**Product Name:** FnSound (working title)
**Platform:** macOS 13.0+ (Ventura and later)
**Distribution:** Direct (Gumroad/web) with App Store optionality
**Target User:** Non-technical users who want a fun sound effect when pressing the fn key

### User Journey

1. Download DMG from website
1. Drag app to Applications
1. Launch app (appears in menu bar only)
1. Grant Input Monitoring permission (one-time system dialog)
1. Select a sound file via file picker
1. Press fn key alone → sound plays
1. fn + other key → normal behavior, no sound

-----

## Technical Architecture

### High-Level Components

```
┌─────────────────────────────────────────────────────────┐
│                    FnSoundApp                           │
├─────────────────────────────────────────────────────────┤
│  App Entry Point                                        │
│    └─ @main App struct (SwiftUI lifecycle)              │
│    └─ LSUIElement = true (menu bar only, no dock)       │
├─────────────────────────────────────────────────────────┤
│  KeyMonitor (Core Logic)                                │
│    └─ CGEventTap (flagsChanged + keyDown events)        │
│    └─ Detects fn key via CGEventFlags.maskSecondaryFn   │
│    └─ Timer-based "fn alone" detection                  │
│        - fn down → start timer (configurable delay)     │
│        - any keyDown → cancel timer                     │
│        - fn up + timer valid → trigger sound            │
├─────────────────────────────────────────────────────────┤
│  SoundPlayer                                            │
│    └─ AVAudioPlayer for sound playback                  │
│    └─ Handles user-selected audio files                 │
├─────────────────────────────────────────────────────────┤
│  SettingsManager                                        │
│    └─ UserDefaults for persistence                      │
│    └─ Security-scoped bookmarks for file access         │
├─────────────────────────────────────────────────────────┤
│  UI Layer (SwiftUI)                                     │
│    └─ MenuBarExtra (menu bar icon + dropdown)           │
│    └─ Settings window (sound selection, delay config)   │
│    └─ Onboarding/permission request flow                │
└─────────────────────────────────────────────────────────┘
```

### Key Detection Logic (Detailed)

The fn key is a modifier key, so it triggers `flagsChanged` events, not `keyDown`. The challenge is distinguishing "fn pressed alone" from "fn used as modifier."

**State Machine:**

```
                    ┌──────────────┐
         ┌─────────│    IDLE      │─────────┐
         │         └──────────────┘         │
         │                │                 │
    fn released      fn pressed        other key
    (no action)           │            (no action)
         │                ▼                 │
         │         ┌──────────────┐         │
         └─────────│   WAITING    │─────────┘
                   │ (timer running)        │
                   └──────────────┘         │
                          │                 │
              ┌───────────┼───────────┐     │
              │           │           │     │
         timer fires  fn released  other key pressed
              │      (timer valid)    │     │
              ▼           │           ▼     │
        ┌─────────┐       │    ┌──────────┐ │
        │ TRIGGER │◄──────┘    │  CANCEL  │◄┘
        │ (play)  │            │(modifier)│
        └─────────┘            └──────────┘
```

**Implementation Notes:**

- Default delay: 300-500ms (configurable in settings)
- Timer should be `DispatchSourceTimer` or `Task.sleep` for precision
- Must handle edge case: fn held down for extended period (timer fires while still held)

-----

## File Structure

```
FnSound/
├── FnSound.xcodeproj
├── FnSound/
│   ├── FnSoundApp.swift              # @main entry point
│   ├── Info.plist                     # App configuration
│   ├── FnSound.entitlements          # Sandbox + hardened runtime
│   ├── Assets.xcassets/              # App icon, menu bar icon
│   │
│   ├── Core/
│   │   ├── KeyMonitor.swift          # CGEventTap logic
│   │   ├── SoundPlayer.swift         # AVAudioPlayer wrapper
│   │   └── SettingsManager.swift     # UserDefaults + bookmarks
│   │
│   ├── Views/
│   │   ├── MenuBarView.swift         # MenuBarExtra content
│   │   ├── SettingsView.swift        # Settings window
│   │   └── OnboardingView.swift      # Permission request UI
│   │
│   └── Utilities/
│       ├── Permissions.swift         # Permission check helpers
│       └── SecurityScopedBookmark.swift
│
└── README.md
```

-----

## Implementation Plan

### Phase 1: Project Setup (Agent Task)

**1.1 Create Xcode Project**

```bash
# Create project directory
mkdir -p ~/Developer/FnSound
cd ~/Developer/FnSound
```

Create new Xcode project with these settings:

- **Template:** macOS → App
- **Interface:** SwiftUI
- **Language:** Swift
- **Product Name:** FnSound
- **Organization Identifier:** (user will provide, e.g., `com.yourname`)
- **Bundle Identifier:** `com.yourname.fnsound`

**1.2 Configure Project Settings**

In Xcode project settings:

**Signing & Capabilities tab:**

- Enable "App Sandbox"
- Enable "Hardened Runtime"

**Info.plist additions:**

```xml
<!-- Menu bar only app (no dock icon) -->
<key>LSUIElement</key>
<true/>

<!-- Minimum macOS version -->
<key>LSMinimumSystemVersion</key>
<string>13.0</string>

<!-- Permission descriptions -->
<key>NSAppleEventsUsageDescription</key>
<string>FnSound needs this permission to play sounds.</string>
```

**Entitlements file (FnSound.entitlements):**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-only</key>
    <true/>
    <key>com.apple.security.files.bookmarks.app-scope</key>
    <true/>
</dict>
</plist>
```

**Note:** Input Monitoring permission does NOT require an entitlement. The system handles it automatically when CGEventTap is created.

-----

### Phase 2: Core Implementation (Agent Task)

**2.1 KeyMonitor.swift**

This is the most critical component. Reference documentation:

- [CGEvent.tapCreate](https://developer.apple.com/documentation/coregraphics/cgevent/1454426-tapcreate)
- [CGEventFlags](https://developer.apple.com/documentation/coregraphics/cgeventflags)
- [CGEventType.flagsChanged](https://developer.apple.com/documentation/coregraphics/cgeventtype/flagschanged)
- [CGPreflightListenEventAccess](https://developer.apple.com/documentation/coregraphics/3229356-cgpreflightlisteneventaccess)
- [CGRequestListenEventAccess](https://developer.apple.com/documentation/coregraphics/3229557-cgrequestlisteneventaccess)

**Key implementation details:**

```swift
import Cocoa
import CoreGraphics

class KeyMonitor: ObservableObject {
    @Published var isMonitoring = false
    @Published var hasPermission = false

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var fnPressedTime: Date?
    private var triggerTimer: DispatchSourceTimer?

    var onTrigger: (() -> Void)?
    var triggerDelay: TimeInterval = 0.4  // 400ms default

    // Check/request Input Monitoring permission
    func checkPermission() -> Bool {
        return CGPreflightListenEventAccess()
    }

    func requestPermission() {
        CGRequestListenEventAccess()
    }

    func start() {
        // Create event tap for flagsChanged AND keyDown
        // flagsChanged: detect fn press/release
        // keyDown: cancel trigger if fn used as modifier

        let eventMask = (1 << CGEventType.flagsChanged.rawValue) |
                        (1 << CGEventType.keyDown.rawValue)

        // CGEvent.tapCreate with .listenOnly option
        // Callback checks CGEventFlags for maskSecondaryFn
    }

    func stop() {
        // Invalidate tap, remove from run loop
    }

    private func handleFlagsChanged(_ flags: CGEventFlags) {
        let fnPressed = flags.contains(.maskSecondaryFn)

        if fnPressed && fnPressedTime == nil {
            // fn just pressed - start timer
            fnPressedTime = Date()
            startTriggerTimer()
        } else if !fnPressed && fnPressedTime != nil {
            // fn released - check if timer still valid
            if triggerTimer != nil {
                // Timer hasn't fired and no other key pressed
                trigger()
            }
            fnPressedTime = nil
            cancelTriggerTimer()
        }
    }

    private func handleKeyDown() {
        // Any key pressed while fn is down = cancel trigger
        cancelTriggerTimer()
        fnPressedTime = nil  // Reset, don't trigger on release
    }

    private func trigger() {
        onTrigger?()
    }
}
```

**Critical CGEventTap implementation notes:**

1. The callback must be a C function pointer (not a closure that captures context). Use `Unmanaged` to pass `self`:

```swift
let info = Unmanaged.passRetained(self).toOpaque()

let tap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .listenOnly,
    eventsOfInterest: CGEventMask(eventMask),
    callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
        guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
        let monitor = Unmanaged<KeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
        monitor.handleEvent(type: type, event: event)
        return Unmanaged.passUnretained(event)
    },
    userInfo: info
)
```

1. Must handle `tapDisabledByTimeout` and `tapDisabledByUserInput` events to re-enable the tap:

```swift
if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
    if let tap = eventTap {
        CGEvent.tapEnable(tap: tap, enable: true)
    }
    return
}
```

1. Add tap to run loop:

```swift
let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)
```

**2.2 SoundPlayer.swift**

Reference: [AVAudioPlayer](https://developer.apple.com/documentation/avfaudio/avaudioplayer)

```swift
import AVFoundation

class SoundPlayer: ObservableObject {
    private var audioPlayer: AVAudioPlayer?
    @Published var currentSoundURL: URL?
    @Published var isPlaying = false

    func loadSound(from url: URL) throws {
        // For sandboxed apps, must start accessing security-scoped resource
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart { url.stopAccessingSecurityScopedResource() }
        }

        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.prepareToPlay()
        currentSoundURL = url
    }

    func play() {
        audioPlayer?.currentTime = 0
        audioPlayer?.play()
    }
}
```

**2.3 SettingsManager.swift**

Reference: [Security-Scoped Bookmarks](https://developer.apple.com/documentation/foundation/nsurl/1417051-bookmarkdata)

```swift
import Foundation

class SettingsManager: ObservableObject {
    private let defaults = UserDefaults.standard

    private let soundBookmarkKey = "soundFileBookmark"
    private let triggerDelayKey = "triggerDelay"
    private let enabledKey = "isEnabled"

    @Published var triggerDelay: TimeInterval {
        didSet { defaults.set(triggerDelay, forKey: triggerDelayKey) }
    }

    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: enabledKey) }
    }

    init() {
        self.triggerDelay = defaults.double(forKey: triggerDelayKey)
        if self.triggerDelay == 0 { self.triggerDelay = 0.4 }
        self.isEnabled = defaults.bool(forKey: enabledKey)
    }

    // Save security-scoped bookmark for sound file
    func saveSoundBookmark(for url: URL) throws {
        let bookmarkData = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        defaults.set(bookmarkData, forKey: soundBookmarkKey)
    }

    // Resolve bookmark to URL
    func loadSoundURL() -> URL? {
        guard let bookmarkData = defaults.data(forKey: soundBookmarkKey) else {
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

        if isStale {
            // Bookmark is stale, need to recreate
            try? saveSoundBookmark(for: url)
        }

        return url
    }
}
```

-----

### Phase 3: UI Implementation (Agent Task)

**3.1 FnSoundApp.swift (Entry Point)**

```swift
import SwiftUI

@main
struct FnSoundApp: App {
    @StateObject private var keyMonitor = KeyMonitor()
    @StateObject private var soundPlayer = SoundPlayer()
    @StateObject private var settings = SettingsManager()

    var body: some Scene {
        MenuBarExtra("FnSound", systemImage: "speaker.wave.2.fill") {
            MenuBarView()
                .environmentObject(keyMonitor)
                .environmentObject(soundPlayer)
                .environmentObject(settings)
        }

        Settings {
            SettingsView()
                .environmentObject(keyMonitor)
                .environmentObject(soundPlayer)
                .environmentObject(settings)
        }
    }
}
```

**3.2 MenuBarView.swift**

```swift
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var keyMonitor: KeyMonitor
    @EnvironmentObject var soundPlayer: SoundPlayer
    @EnvironmentObject var settings: SettingsManager

    var body: some View {
        VStack {
            // Status
            if !keyMonitor.hasPermission {
                Button("Grant Input Monitoring Permission...") {
                    keyMonitor.requestPermission()
                }
            } else {
                Toggle("Enabled", isOn: $settings.isEnabled)
                    .onChange(of: settings.isEnabled) { enabled in
                        if enabled { keyMonitor.start() }
                        else { keyMonitor.stop() }
                    }
            }

            Divider()

            // Sound selection
            if let soundURL = soundPlayer.currentSoundURL {
                Text("Sound: \(soundURL.lastPathComponent)")
                    .font(.caption)
            } else {
                Text("No sound selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button("Choose Sound...") {
                selectSoundFile()
            }

            Button("Test Sound") {
                soundPlayer.play()
            }
            .disabled(soundPlayer.currentSoundURL == nil)

            Divider()

            SettingsLink {
                Text("Settings...")
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(8)
        .onAppear {
            setupApp()
        }
    }

    private func setupApp() {
        // Check permission
        keyMonitor.hasPermission = keyMonitor.checkPermission()

        // Load saved sound
        if let savedURL = settings.loadSoundURL() {
            try? soundPlayer.loadSound(from: savedURL)
        }

        // Connect trigger
        keyMonitor.onTrigger = {
            soundPlayer.play()
        }

        // Start monitoring if enabled and permitted
        if settings.isEnabled && keyMonitor.hasPermission {
            keyMonitor.start()
        }
    }

    private func selectSoundFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio, .mp3, .wav, .aiff]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try soundPlayer.loadSound(from: url)
                try settings.saveSoundBookmark(for: url)
            } catch {
                print("Failed to load sound: \(error)")
            }
        }
    }
}
```

**3.3 SettingsView.swift**

```swift
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var keyMonitor: KeyMonitor
    @EnvironmentObject var settings: SettingsManager

    var body: some View {
        Form {
            Section("Trigger Settings") {
                HStack {
                    Text("Delay before trigger:")
                    Slider(value: $settings.triggerDelay, in: 0.1...1.0, step: 0.1)
                    Text("\(settings.triggerDelay, specifier: "%.1f")s")
                        .monospacedDigit()
                        .frame(width: 40)
                }
                .onChange(of: settings.triggerDelay) { newValue in
                    keyMonitor.triggerDelay = newValue
                }

                Text("Shorter = faster response, but may trigger accidentally when using fn+key combos")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Permissions") {
                HStack {
                    Image(systemName: keyMonitor.hasPermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(keyMonitor.hasPermission ? .green : .red)
                    Text("Input Monitoring")
                    Spacer()
                    if !keyMonitor.hasPermission {
                        Button("Grant Access") {
                            keyMonitor.requestPermission()
                        }
                    }
                }
            }

            Section("About") {
                Text("FnSound v1.0.0")
                Link("GitHub", destination: URL(string: "https://github.com/yourname/fnsound")!)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 300)
    }
}
```

-----

### Phase 4: Polish & Testing (Agent Task)

**4.1 App Icon**

Create a simple app icon using SF Symbols or a basic design:

- 16x16, 32x32, 128x128, 256x256, 512x512 sizes
- Menu bar icon: 18x18 template image (single color, will adapt to system)

For MVP, use SF Symbols in code:

```swift
MenuBarExtra("FnSound", systemImage: "speaker.wave.2.fill")
```

**4.2 Testing Checklist**

- [ ] App launches as menu bar only (no dock icon)
- [ ] Permission dialog appears on first launch
- [ ] After granting permission, app can detect fn key
- [ ] fn + any key does NOT trigger sound
- [ ] fn alone (held for delay period) DOES trigger sound
- [ ] fn tap-and-release (faster than delay) does NOT trigger
- [ ] Sound file picker works
- [ ] Selected sound persists after app restart
- [ ] Settings changes persist after app restart
- [ ] Quit menu item works

**4.3 Common Issues & Fixes**

|Issue                         |Cause                                |Fix                                              |
|------------------------------|-------------------------------------|-------------------------------------------------|
|CGEventTap returns nil        |No Input Monitoring permission       |Call `CGRequestListenEventAccess()` first        |
|Sound doesn't play            |Security-scoped resource not accessed|Call `url.startAccessingSecurityScopedResource()`|
|App appears in dock           |Missing LSUIElement                  |Add `<key>LSUIElement</key><true/>` to Info.plist|
|Tap stops working randomly    |Tap disabled by system               |Handle `.tapDisabledByTimeout` event type        |
|Bookmark is stale after reboot|Normal behavior                      |Recreate bookmark when stale flag is true        |

-----

## Phase 5: Manual Steps (Human Task)

These steps require human intervention and cannot be automated:

### 5.1 Prerequisites (Before Agent Starts)

1. **Install Xcode** from Mac App Store (if not already installed)
- Version 15.0+ recommended
- After install, run once to accept license: `sudo xcodebuild -license accept`
1. **Apple Developer Account**
- Ensure you're signed into Xcode with your Apple ID
- Xcode → Settings → Accounts → Add Apple ID
1. **Provide Organization Identifier**
- Decide on bundle ID format, e.g., `com.yourname.fnsound`
- Tell the agent this value before project creation

### 5.2 Post-Development (After Agent Completes)

1. **Test the App Locally**

   ```bash
   # Build and run from Xcode
   # Or from command line:
   cd ~/Developer/FnSound
   xcodebuild -scheme FnSound -configuration Debug build
   open build/Debug/FnSound.app
   ```
1. **Grant Input Monitoring Permission**
- First launch will show permission dialog
- Or manually: System Settings → Privacy & Security → Input Monitoring → Enable FnSound
1. **Prepare for Distribution**

   a. **Archive the app:**
- Xcode → Product → Archive
- Wait for archive to complete

   b. **Export with Developer ID:**
- In Organizer window, select archive
- Click "Distribute App"
- Select "Developer ID"
- Select "Upload" (to notarize)
- Wait for notarization (usually 2-5 minutes)
- Export the notarized .app

   c. **Create DMG:**

   ```bash
   # Install create-dmg
   brew install create-dmg

   # Create DMG
   create-dmg \
     --volname "FnSound" \
     --window-pos 200 120 \
     --window-size 600 400 \
     --icon-size 100 \
     --icon "FnSound.app" 175 190 \
     --hide-extension "FnSound.app" \
     --app-drop-link 425 190 \
     "FnSound.dmg" \
     "/path/to/exported/FnSound.app"
   ```

   d. **Notarize DMG:**

   ```bash
   # Store credentials (one-time)
   xcrun notarytool store-credentials "fnsound-profile" \
     --apple-id "your@email.com" \
     --team-id "YOURTEAMID" \
     --password "app-specific-password"

   # Submit for notarization
   xcrun notarytool submit FnSound.dmg \
     --keychain-profile "fnsound-profile" \
     --wait

   # Staple the ticket
   xcrun stapler staple FnSound.dmg
   ```

   e. **Verify:**

   ```bash
   spctl --assess --type open --context context:primary-signature -v FnSound.dmg
   # Should output: FnSound.dmg: accepted, source=Notarized Developer ID
   ```
1. **Upload to Gumroad/Website**
- Upload the notarized, stapled DMG
- Create product listing with description
- Test download and install on a clean Mac

-----

## API Reference Links

### Core APIs

- [CGEvent.tapCreate](https://developer.apple.com/documentation/coregraphics/cgevent/1454426-tapcreate)
- [CGEventFlags](https://developer.apple.com/documentation/coregraphics/cgeventflags)
- [CGEventFlags.maskSecondaryFn](https://developer.apple.com/documentation/coregraphics/cgeventflags/masksecondaryfn) — The fn key flag
- [CGPreflightListenEventAccess](https://developer.apple.com/documentation/coregraphics/3229556-cgpreflightlisteneventaccess)
- [CGRequestListenEventAccess](https://developer.apple.com/documentation/coregraphics/3229557-cgrequestlisteneventaccess)

### Audio

- [AVAudioPlayer](https://developer.apple.com/documentation/avfaudio/avaudioplayer)

### SwiftUI

- [MenuBarExtra](https://developer.apple.com/documentation/swiftui/menubarextra)
- [Settings Scene](https://developer.apple.com/documentation/swiftui/settings)

### File Access

- [Security-Scoped Bookmarks](https://developer.apple.com/documentation/foundation/nsurl/1417051-bookmarkdata)
- [NSOpenPanel](https://developer.apple.com/documentation/appkit/nsopenpanel)

### Distribution

- [Notarizing macOS Software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [Developer ID Distribution](https://developer.apple.com/developer-id/)

-----

## Stretch Goals (Future Iterations)

### Stretch Goal 1: Configurable Trigger Key

Allow user to select any modifier key (fn, Caps Lock, etc.) or key combination.

**Implementation:**

- Add picker in Settings for modifier selection
- Modify KeyMonitor to check for selected modifier flag
- Store selection in UserDefaults

### Stretch Goal 2: Import Sound from Video/Audio

Allow user to import a media file and trim a clip.

**Implementation:**

- Use AVAsset to load media
- AVPlayer preview with scrubber
- AVAssetExportSession to extract audio clip
- Store extracted clip in app container

### Stretch Goal 3: Download Sound from URL

Allow user to paste URL and download audio.

**Implementation:**

- URLSession download task
- Validate file is audio
- Store in app container

-----

## Summary for Agent

**Your task:** Implement Phases 1-4 autonomously.

**Start with:**

1. Create Xcode project (Phase 1)
1. Implement KeyMonitor.swift with CGEventTap (Phase 2.1) — this is the hardest part
1. Implement SoundPlayer.swift (Phase 2.2)
1. Implement SettingsManager.swift (Phase 2.3)
1. Implement UI views (Phase 3)
1. Test and debug (Phase 4)

**Key files to create:**

- `FnSoundApp.swift`
- `Core/KeyMonitor.swift`
- `Core/SoundPlayer.swift`
- `Core/SettingsManager.swift`
- `Views/MenuBarView.swift`
- `Views/SettingsView.swift`

**Human will handle:**

- Xcode installation (if needed)
- Apple ID sign-in
- Providing bundle identifier
- Testing with actual Input Monitoring permission
- Final distribution (archive, notarize, DMG creation)

**Output:** A working Xcode project that builds and runs, implementing the core fn-key-to-sound functionality.
