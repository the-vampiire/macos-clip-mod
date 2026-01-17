# FnSound / LIFN

A macOS menu bar app that plays a sound when you press the fn key alone. Supports branding for custom versions (e.g., LIFN).

## Project Structure

```
macos-clip-mod/
├── FnSound/                    # Xcode project (you are here)
│   ├── FnSound/
│   │   ├── Core/               # Business logic
│   │   │   ├── KeyMonitor.swift      # CGEventTap for fn key detection
│   │   │   ├── SoundPlayer.swift     # AVAudioPlayer wrapper
│   │   │   ├── SettingsManager.swift # UserDefaults persistence
│   │   │   ├── ToastyManager.swift   # Popup + random timer
│   │   │   ├── BrandManager.swift    # Brand config loader
│   │   │   └── UpdaterManager.swift  # Sparkle integration
│   │   └── Views/              # SwiftUI views
│   │       ├── MenuBarView.swift     # Menu bar dropdown
│   │       └── SettingsView.swift    # Settings window
│   └── FnSound.xcodeproj
├── Branding/
│   └── LIFN/                   # Brand-specific assets
│       ├── brand.json          # Brand config (name, bundle ID, version)
│       ├── Sounds/             # Audio files
│       └── Icons/              # App + menu bar icons
├── Scripts/
│   ├── build-brand.sh          # Build branded app
│   └── create-dmg.sh           # Create DMG for distribution
├── CHANGELOG.md                # Release notes (used by CI and Sparkle)
└── .github/workflows/          # CI/CD
```

## Building

### Local Development (quick)

```bash
# From repo root
cd /Users/vamp/magic/projects/macos-clip-mod

# Build Release configuration
./Scripts/build-brand.sh LIFN Release

# Output: build/LIFN/LIFN.app
```

### Install Locally

```bash
# Kill running instance
pkill -x LIFN || true

# Copy to Applications
cp -R build/LIFN/LIFN.app /Applications/

# Launch
open /Applications/LIFN.app
```

### One-liner: Build and Install

```bash
cd /Users/vamp/magic/projects/macos-clip-mod && ./Scripts/build-brand.sh LIFN Release && pkill -x LIFN || true && cp -R build/LIFN/LIFN.app /Applications/ && open /Applications/LIFN.app
```

## Releasing New Versions

### 1. Update version and changelog

Edit `Branding/LIFN/brand.json`:
```json
{
  "version": "1.0.5"
}
```

Edit `CHANGELOG.md`:
```markdown
## [1.0.5] - 2026-01-17
- Your changes here
```

### 2. Commit and tag

```bash
git add -A
git commit -m "Release v1.0.5: Description"
git tag v1.0.5
git push origin master --tags
```

### 3. CI handles the rest

The GitHub Action will:
- Build the branded app
- Sign with Developer ID certificate
- Create and notarize DMG
- Sign with Sparkle EdDSA key
- Create GitHub Release
- Update appcast.xml on gh-pages

## Key Concepts

### Branding System

The app is generic (`FnSound`) but gets branded at build time:
- `brand.json` defines name, bundle ID, version
- Sounds copied to app bundle
- Icons compiled into .icns
- Info.plist updated with brand values

### Settings Storage

All settings in `UserDefaults.standard`:
- `triggerDelay` - Delay before fn triggers (0.1-1.0s)
- `isEnabled` - Whether monitoring is active
- `launchAtLogin` - Auto-start via SMAppService
- `soundFileBookmark` - Security-scoped bookmark for custom sound
- `toasty*` - Popup settings
- `randomTimer*` - Random trigger settings

### Permissions

Requires **Input Monitoring** permission (Privacy & Security > Input Monitoring).

The app is NOT sandboxed (`com.apple.security.app-sandbox = false`) because:
- CGEventTap requires it for fn key detection
- Sparkle updates need file system access

### Sparkle Auto-Updates

- Appcast URL: `https://the-vampiire.github.io/macos-clip-mod/appcast.xml`
- EdDSA signature verification
- Hosted on gh-pages branch

## Common Tasks

### Add a new setting

1. Add key to `SettingsManager.Keys`
2. Add `@Published var` property with `didSet` to persist
3. Load in `init()` with sensible default
4. Add UI in `SettingsView.swift` or `MenuBarView.swift`

### Test without install

```bash
open build/LIFN/LIFN.app
```

### Check code signing

```bash
codesign -dvvv build/LIFN/LIFN.app
```

### View app logs

```bash
log stream --predicate 'subsystem == "com.lifn.fnsound"' --level debug
```
