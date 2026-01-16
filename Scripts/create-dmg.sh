#!/bin/bash
set -e

# Create DMG and optionally notarize it for distribution
#
# Usage:
#   ./create-dmg.sh <path-to-app> [--notarize]
#
# Examples:
#   ./create-dmg.sh /path/to/LIFN.app                    # Just create DMG
#   ./create-dmg.sh /path/to/LIFN.app --notarize         # Create and notarize
#
# Prerequisites:
#   brew install create-dmg
#
# For notarization, first store your credentials (one-time):
#   xcrun notarytool store-credentials "apple-notary" \
#     --apple-id "your@email.com" \
#     --team-id "YOURTEAMID" \
#     --password "app-specific-password"
#
# Get your Team ID: https://developer.apple.com/account → Membership
# Create app-specific password: https://appleid.apple.com → App-Specific Passwords

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

APP_PATH="$1"
NOTARIZE=false
KEYCHAIN_PROFILE="apple-notary"

# Parse arguments
for arg in "$@"; do
    case $arg in
        --notarize)
            NOTARIZE=true
            shift
            ;;
        --profile=*)
            KEYCHAIN_PROFILE="${arg#*=}"
            shift
            ;;
    esac
done

# Validate input
if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo "Usage: $0 <path-to-app> [--notarize] [--profile=keychain-profile]"
    echo ""
    echo "Examples:"
    echo "  $0 build/LIFN/LIFN.app"
    echo "  $0 build/LIFN/LIFN.app --notarize"
    echo ""
    exit 1
fi

# Check for create-dmg
if ! command -v create-dmg &> /dev/null; then
    echo "Error: create-dmg not found. Install it with:"
    echo "  brew install create-dmg"
    exit 1
fi

# Extract app name and create output paths
APP_NAME="$(basename "$APP_PATH" .app)"
OUTPUT_DIR="$PROJECT_ROOT/dist"
DMG_PATH="$OUTPUT_DIR/${APP_NAME}.dmg"

mkdir -p "$OUTPUT_DIR"

# Remove existing DMG if present
rm -f "$DMG_PATH"

echo "Creating DMG for $APP_NAME..."
echo "  Source: $APP_PATH"
echo "  Output: $DMG_PATH"
echo ""

# Create the DMG with a nice installer layout
create-dmg \
    --volname "$APP_NAME" \
    --volicon "$APP_PATH/Contents/Resources/AppIcon.icns" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon "$APP_NAME.app" 175 190 \
    --hide-extension "$APP_NAME.app" \
    --app-drop-link 425 190 \
    --no-internet-enable \
    "$DMG_PATH" \
    "$APP_PATH" \
    2>/dev/null || {
        # create-dmg returns non-zero even on success sometimes
        if [ -f "$DMG_PATH" ]; then
            echo "DMG created (with warnings)"
        else
            echo "Error: Failed to create DMG"
            exit 1
        fi
    }

echo ""
echo "DMG created: $DMG_PATH"
echo "Size: $(du -h "$DMG_PATH" | cut -f1)"

# Set the DMG file's icon (not just the volume icon)
ICON_PATH="$APP_PATH/Contents/Resources/AppIcon.icns"
if [ -f "$ICON_PATH" ]; then
    echo "Setting DMG file icon..."

    # Create a temp directory for icon work
    ICON_TEMP=$(mktemp -d)

    # Use sips to convert icns to iconset, then to a resource
    # DeRez/Rez approach to set custom icon on the DMG file
    sips -i "$ICON_PATH" >/dev/null 2>&1 || true

    # Copy icon to DMG using resource fork
    # This uses the Finder's "paste icon" approach via script
    osascript <<EOF
use framework "Foundation"
use framework "AppKit"
use scripting additions

set iconFile to POSIX file "$ICON_PATH"
set dmgFile to POSIX file "$DMG_PATH"

set iconImage to current application's NSImage's alloc()'s initWithContentsOfFile:"$ICON_PATH"
current application's NSWorkspace's sharedWorkspace()'s setIcon:iconImage forFile:"$DMG_PATH" options:0
EOF

    rm -rf "$ICON_TEMP"
    echo "DMG file icon set"
fi

# Notarize if requested
if [ "$NOTARIZE" = true ]; then
    echo ""
    echo "Submitting for notarization..."
    echo "Using keychain profile: $KEYCHAIN_PROFILE"
    echo ""

    # Check if credentials exist
    if ! xcrun notarytool history --keychain-profile "$KEYCHAIN_PROFILE" &>/dev/null; then
        echo "Error: Keychain profile '$KEYCHAIN_PROFILE' not found."
        echo ""
        echo "Store your credentials first:"
        echo "  xcrun notarytool store-credentials \"$KEYCHAIN_PROFILE\" \\"
        echo "    --apple-id \"your@email.com\" \\"
        echo "    --team-id \"YOURTEAMID\" \\"
        echo "    --password \"app-specific-password\""
        echo ""
        exit 1
    fi

    # Submit for notarization and wait
    xcrun notarytool submit "$DMG_PATH" \
        --keychain-profile "$KEYCHAIN_PROFILE" \
        --wait

    echo ""
    echo "Stapling notarization ticket..."
    xcrun stapler staple "$DMG_PATH"

    echo ""
    echo "Verifying notarization..."
    spctl --assess --type open --context context:primary-signature -v "$DMG_PATH" 2>&1 || true
fi

echo ""
echo "========================================="
echo "Distribution package ready!"
echo "========================================="
echo ""
echo "  $DMG_PATH"
echo ""
if [ "$NOTARIZE" = true ]; then
    echo "This DMG is notarized and ready to distribute."
else
    echo "Note: This DMG is NOT notarized."
    echo "Recipients may see Gatekeeper warnings."
    echo ""
    echo "To notarize, run:"
    echo "  $0 $APP_PATH --notarize"
fi
echo ""
