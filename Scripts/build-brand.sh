#!/bin/bash
set -e

# Build script for creating branded versions of FnSound
# Usage: ./build-brand.sh <brand_name> [configuration]
# Example: ./build-brand.sh LIFN Release

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BRAND_NAME="${1:-FnSound}"
CONFIGURATION="${2:-Release}"

# Paths
XCODE_PROJECT="$PROJECT_ROOT/FnSound/FnSound.xcodeproj"
BRAND_DIR="$PROJECT_ROOT/Branding/$BRAND_NAME"
BUILD_DIR="$PROJECT_ROOT/build"
OUTPUT_DIR="$BUILD_DIR/$BRAND_NAME"

echo "Building $BRAND_NAME ($CONFIGURATION)..."

# Check if brand exists (skip for generic FnSound)
if [ "$BRAND_NAME" != "FnSound" ]; then
    if [ ! -d "$BRAND_DIR" ]; then
        echo "Error: Brand directory not found: $BRAND_DIR"
        exit 1
    fi

    if [ ! -f "$BRAND_DIR/brand.json" ]; then
        echo "Error: brand.json not found in $BRAND_DIR"
        exit 1
    fi
fi

# Create build directory
mkdir -p "$OUTPUT_DIR"

# Build the app
echo "Building Xcode project..."
xcodebuild -project "$XCODE_PROJECT" \
    -scheme FnSound \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    build

# Find the built app
BUILT_APP="$BUILD_DIR/DerivedData/Build/Products/$CONFIGURATION/FnSound.app"

if [ ! -d "$BUILT_APP" ]; then
    echo "Error: Built app not found at $BUILT_APP"
    exit 1
fi

# Copy app to output directory
if [ "$BRAND_NAME" = "FnSound" ]; then
    APP_NAME="FnSound.app"
else
    # Read app name from brand.json
    APP_NAME="$(python3 -c "import json; print(json.load(open('$BRAND_DIR/brand.json'))['appName'])" 2>/dev/null || echo "$BRAND_NAME").app"
fi

OUTPUT_APP="$OUTPUT_DIR/$APP_NAME"
rm -rf "$OUTPUT_APP"
cp -R "$BUILT_APP" "$OUTPUT_APP"

echo "Copied app to $OUTPUT_APP"

# Apply branding if not generic
if [ "$BRAND_NAME" != "FnSound" ] && [ -f "$BRAND_DIR/brand.json" ]; then
    echo "Applying branding..."

    # Read brand config
    BUNDLE_ID="$(python3 -c "import json; print(json.load(open('$BRAND_DIR/brand.json'))['bundleIdentifier'])")"
    DISPLAY_NAME="$(python3 -c "import json; print(json.load(open('$BRAND_DIR/brand.json'))['displayName'])")"
    VERSION="$(python3 -c "import json; print(json.load(open('$BRAND_DIR/brand.json'))['version'])")"

    # Update Info.plist
    INFO_PLIST="$OUTPUT_APP/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$INFO_PLIST"
    /usr/libexec/PlistBuddy -c "Set :CFBundleName $DISPLAY_NAME" "$INFO_PLIST"
    /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $DISPLAY_NAME" "$INFO_PLIST" 2>/dev/null || \
        /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string $DISPLAY_NAME" "$INFO_PLIST"
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$INFO_PLIST"

    # Copy sounds to Resources
    RESOURCES_DIR="$OUTPUT_APP/Contents/Resources"
    SOUNDS_DIR="$RESOURCES_DIR/Sounds"
    mkdir -p "$SOUNDS_DIR"

    if [ -d "$BRAND_DIR/Sounds" ]; then
        cp "$BRAND_DIR/Sounds"/*.mp3 "$SOUNDS_DIR/" 2>/dev/null || true
        cp "$BRAND_DIR/Sounds"/*.wav "$SOUNDS_DIR/" 2>/dev/null || true
        cp "$BRAND_DIR/Sounds"/*.aiff "$SOUNDS_DIR/" 2>/dev/null || true
        echo "Copied sounds to $SOUNDS_DIR"
    fi

    # Copy brand.json to Resources for runtime access
    cp "$BRAND_DIR/brand.json" "$RESOURCES_DIR/"

    # Copy icons if they exist
    if [ -d "$BRAND_DIR/Icons" ]; then
        ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
        mkdir -p "$ICONSET_DIR"

        # Map icons to iconset naming convention
        [ -f "$BRAND_DIR/Icons/icon_16x16.png" ] && cp "$BRAND_DIR/Icons/icon_16x16.png" "$ICONSET_DIR/icon_16x16.png"
        [ -f "$BRAND_DIR/Icons/icon_32x32.png" ] && cp "$BRAND_DIR/Icons/icon_32x32.png" "$ICONSET_DIR/icon_16x16@2x.png"
        [ -f "$BRAND_DIR/Icons/icon_32x32.png" ] && cp "$BRAND_DIR/Icons/icon_32x32.png" "$ICONSET_DIR/icon_32x32.png"
        [ -f "$BRAND_DIR/Icons/icon_64x64.png" ] && cp "$BRAND_DIR/Icons/icon_64x64.png" "$ICONSET_DIR/icon_32x32@2x.png"
        [ -f "$BRAND_DIR/Icons/icon_128x128.png" ] && cp "$BRAND_DIR/Icons/icon_128x128.png" "$ICONSET_DIR/icon_128x128.png"
        [ -f "$BRAND_DIR/Icons/icon_256x256.png" ] && cp "$BRAND_DIR/Icons/icon_256x256.png" "$ICONSET_DIR/icon_128x128@2x.png"
        [ -f "$BRAND_DIR/Icons/icon_256x256.png" ] && cp "$BRAND_DIR/Icons/icon_256x256.png" "$ICONSET_DIR/icon_256x256.png"
        [ -f "$BRAND_DIR/Icons/icon_512x512.png" ] && cp "$BRAND_DIR/Icons/icon_512x512.png" "$ICONSET_DIR/icon_256x256@2x.png"
        [ -f "$BRAND_DIR/Icons/icon_512x512.png" ] && cp "$BRAND_DIR/Icons/icon_512x512.png" "$ICONSET_DIR/icon_512x512.png"
        [ -f "$BRAND_DIR/Icons/icon_1024x1024.png" ] && cp "$BRAND_DIR/Icons/icon_1024x1024.png" "$ICONSET_DIR/icon_512x512@2x.png"

        # Generate icns file
        iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"

        # Update Info.plist to use the icon
        /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$INFO_PLIST" 2>/dev/null || \
            /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$INFO_PLIST"

        # Remove the iconset temp directory
        rm -rf "$ICONSET_DIR"

        echo "Generated and installed app icon"

        # Copy menu bar icons if they exist
        if [ -f "$BRAND_DIR/Icons/menubar_small.png" ]; then
            cp "$BRAND_DIR/Icons/menubar_small.png" "$RESOURCES_DIR/"
            echo "Copied small menu bar icon"
        fi
        if [ -f "$BRAND_DIR/Icons/menubar_large.png" ]; then
            cp "$BRAND_DIR/Icons/menubar_large.png" "$RESOURCES_DIR/"
            echo "Copied large menu bar icon"
        fi
        if [ -f "$BRAND_DIR/Icons/menubar_letter.png" ]; then
            cp "$BRAND_DIR/Icons/menubar_letter.png" "$RESOURCES_DIR/"
            echo "Copied letter menu bar icon"
        fi
    fi

    echo "Branding applied successfully!"
fi

# Re-sign the app with Developer ID certificate
echo "Re-signing app with Developer ID..."

# Find Developer ID certificate
DEVELOPER_ID=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)".*/\1/')
ENTITLEMENTS="$PROJECT_ROOT/FnSound/FnSound/FnSound.entitlements"

# Re-sign Sparkle framework if present (required for notarization and Team ID matching)
SPARKLE_FRAMEWORK="$OUTPUT_APP/Contents/Frameworks/Sparkle.framework"
if [ -d "$SPARKLE_FRAMEWORK" ] && [ -n "$DEVELOPER_ID" ]; then
    echo "Re-signing Sparkle framework..."

    # Re-sign XPC services
    find "$SPARKLE_FRAMEWORK" -name "*.xpc" -type d | while read xpc; do
        codesign --force --deep --timestamp --options runtime \
            --sign "$DEVELOPER_ID" "$xpc" 2>/dev/null || true
    done

    # Re-sign nested apps
    find "$SPARKLE_FRAMEWORK" -name "*.app" -type d | while read app; do
        codesign --force --deep --timestamp --options runtime \
            --sign "$DEVELOPER_ID" "$app" 2>/dev/null || true
    done

    # Re-sign individual binaries
    find "$SPARKLE_FRAMEWORK/Versions/B" -type f -perm +111 ! -name "*.plist" | while read binary; do
        codesign --force --timestamp --options runtime \
            --sign "$DEVELOPER_ID" "$binary" 2>/dev/null || true
    done

    # Re-sign the framework itself
    codesign --force --deep --timestamp --options runtime \
        --sign "$DEVELOPER_ID" "$SPARKLE_FRAMEWORK"

    echo "Sparkle framework re-signed"
fi

if [ -z "$DEVELOPER_ID" ]; then
    echo "Warning: No Developer ID certificate found. Using ad-hoc signing."
    echo "         The app will work locally but won't pass notarization."
    codesign --force --deep --sign - "$OUTPUT_APP"
else
    echo "Using certificate: $DEVELOPER_ID"

    # Sign all executables in MacOS directory (including debug dylibs)
    for file in "$OUTPUT_APP/Contents/MacOS"/*; do
        if [ -f "$file" ]; then
            codesign --force --timestamp --options runtime \
                --sign "$DEVELOPER_ID" \
                --entitlements "$ENTITLEMENTS" \
                "$file"
        fi
    done

    codesign --force --timestamp --options runtime \
        --sign "$DEVELOPER_ID" \
        --entitlements "$ENTITLEMENTS" \
        "$OUTPUT_APP"

    echo "Signed with Developer ID certificate"
fi

echo ""
echo "Build complete!"
echo "Output: $OUTPUT_APP"
echo ""
echo "To run: open \"$OUTPUT_APP\""
echo ""
if [ -n "$DEVELOPER_ID" ]; then
    echo "To create notarized DMG:"
    echo "  ./Scripts/create-dmg.sh \"$OUTPUT_APP\" --notarize"
fi
