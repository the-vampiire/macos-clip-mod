# Release Pipeline Setup

This document explains how to set up the automated release pipeline for LIFN.

## Overview

When you push a tag like `v1.0.0`, GitHub Actions will:
1. Build the app
2. Sign it with your Developer ID certificate
3. Notarize it with Apple
4. Create a DMG
5. Sign the update with Sparkle's EdDSA key
6. Create a GitHub Release with the DMG
7. Update the appcast.xml on GitHub Pages

## Required GitHub Secrets

Go to **Settings → Secrets and variables → Actions** and add these secrets:

### Apple Developer Credentials

| Secret | Description | How to get it |
|--------|-------------|---------------|
| `APPLE_ID` | Your Apple ID email | The email you use for developer.apple.com |
| `APPLE_APP_PASSWORD` | App-specific password | [Create at appleid.apple.com](https://appleid.apple.com) → Security → App-Specific Passwords |
| `APPLE_TEAM_ID` | Your 10-character Team ID | [developer.apple.com/account](https://developer.apple.com/account) → Membership details |

### Code Signing Certificate

| Secret | Description | How to get it |
|--------|-------------|---------------|
| `CERTIFICATE_P12` | Base64-encoded .p12 file | See instructions below |
| `CERTIFICATE_PASSWORD` | Password for the .p12 | The password you set when exporting |

**To export your Developer ID certificate:**

1. Open **Keychain Access**
2. Find your "Developer ID Application" certificate
3. Right-click → Export
4. Choose .p12 format and set a password
5. Base64 encode it:
   ```bash
   base64 -i certificate.p12 | pbcopy
   ```
6. Paste the result as `CERTIFICATE_P12` secret

### Sparkle Signing Key

| Secret | Description |
|--------|-------------|
| `SPARKLE_PRIVATE_KEY` | EdDSA private key for signing updates |

**To generate Sparkle keys:**

1. Download Sparkle:
   ```bash
   curl -L -o sparkle.tar.xz https://github.com/sparkle-project/Sparkle/releases/download/2.6.4/Sparkle-2.6.4.tar.xz
   tar -xf sparkle.tar.xz
   ```

2. Generate a new key pair:
   ```bash
   ./bin/generate_keys
   ```

3. This outputs:
   - **Private key** → Add as `SPARKLE_PRIVATE_KEY` secret
   - **Public key** → Add to `Info.plist` as `SUPublicEDKey`

4. Update Info.plist with the public key (replace placeholder):
   ```xml
   <key>SUPublicEDKey</key>
   <string>YOUR_PUBLIC_KEY_HERE</string>
   ```

## One-Time Setup

### 1. Add Sparkle to Xcode

Open the project in Xcode and:
1. File → Add Package Dependencies
2. Enter: `https://github.com/sparkle-project/Sparkle`
3. Click Add Package
4. Select "Sparkle" (not SparkleCore) → Add to FnSound target

### 2. Enable GitHub Pages

1. Go to repo **Settings → Pages**
2. Source: Deploy from a branch
3. Branch: `gh-pages` / `/ (root)`
4. Save

### 3. Add all secrets

Add the 6 secrets listed above to GitHub Actions secrets.

### 4. Update Info.plist

Replace `SPARKLE_PUBLIC_KEY_PLACEHOLDER` with your actual public key.

## Creating a Release

1. Update version in Xcode (optional - workflow will set it from tag)
2. Commit your changes
3. Create and push a tag:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

4. GitHub Actions will automatically:
   - Build, sign, notarize
   - Create DMG
   - Create GitHub Release
   - Update appcast

Or trigger manually:
1. Go to Actions → "Build, Notarize & Release"
2. Click "Run workflow"
3. Enter version number
4. Click "Run workflow"

## Troubleshooting

### "No signing identity found"
- Ensure `CERTIFICATE_P12` is properly base64-encoded
- Verify the certificate is a "Developer ID Application" certificate

### "Notarization failed"
- Check `APPLE_ID` and `APPLE_APP_PASSWORD` are correct
- Ensure the app-specific password is valid (they can expire)

### "Sparkle signature invalid"
- Regenerate keys and update both the secret and Info.plist
- Ensure the private key doesn't have extra whitespace

## Security Notes

- Secrets are encrypted and never exposed in logs
- The keychain is created fresh for each build and deleted after
- Private keys are written to temp files and cleaned up
