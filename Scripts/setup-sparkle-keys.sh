#!/bin/bash
# Setup script for generating Sparkle EdDSA keys
# Run this once to generate keys for signing updates

set -e

echo "=== Sparkle Key Generator ==="
echo ""

# Download Sparkle if not present
SPARKLE_VERSION="2.6.4"
SPARKLE_DIR="$HOME/.sparkle-tools"

if [ ! -d "$SPARKLE_DIR" ]; then
    echo "Downloading Sparkle tools..."
    mkdir -p "$SPARKLE_DIR"
    curl -L -o /tmp/sparkle.tar.xz "https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz"
    tar -xf /tmp/sparkle.tar.xz -C "$SPARKLE_DIR"
    rm /tmp/sparkle.tar.xz
    echo "Downloaded to $SPARKLE_DIR"
fi

echo ""
echo "Generating new EdDSA key pair..."
echo ""

# Generate keys
"$SPARKLE_DIR/bin/generate_keys"

echo ""
echo "=== IMPORTANT ==="
echo ""
echo "1. Copy the PRIVATE key above and add it as a GitHub secret:"
echo "   Settings → Secrets → Actions → New secret"
echo "   Name: SPARKLE_PRIVATE_KEY"
echo ""
echo "2. Copy the PUBLIC key above and update FnSound/FnSound/Info.plist:"
echo "   Replace 'SPARKLE_PUBLIC_KEY_PLACEHOLDER' with your public key"
echo ""
echo "3. SAVE THE PRIVATE KEY SECURELY - you cannot regenerate it!"
echo "   If you lose it, you'll need to generate new keys and release"
echo "   a new version with the new public key."
echo ""
