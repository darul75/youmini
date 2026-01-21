#!/bin/bash

# YouTubeMini .app Builder Script
# Builds and packages the Swift application into a distributable .app bundle

set -e  # Exit on any error

# Read version from VERSION file
VERSION=$(cat VERSION)

# Read build number
BUILD_NUMBER=$(cat BUILD_NUMBER)

echo "🚀 Building YouTubeMini.app version $VERSION (build $BUILD_NUMBER)..."

# Clean previous builds
echo "🧹 Cleaning previous builds..."
swift package clean

# Build release binary
echo "🔨 Building release binary..."
swift build -c release

# Create distribution directory
echo "📁 Creating dist directory..."
rm -rf dist
mkdir -p dist/YouTubeMini.app/Contents/MacOS
mkdir -p dist/YouTubeMini.app/Contents/Resources

# Create Info.plist
echo "📝 Creating Info.plist..."
cat > dist/YouTubeMini.app/Contents/Info.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>youtube-mini</string>
    <key>CFBundleIdentifier</key>
    <string>com.youtube.mini</string>
    <key>CFBundleName</key>
    <string>YouTubeMini</string>
    <key>CFBundleVersion</key>
    <string>$VERSION.$BUILD_NUMBER</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>This app needs to control Google Chrome to play YouTube videos.</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>MacOSX</string>
    </array>
    <key>LSMinimumSystemVersion</key>
    <string>10.15</string>
</dict>
</plist>
EOF

# Copy executable
echo "📋 Copying executable..."
cp .build/release/youtube-mini dist/YouTubeMini.app/Contents/MacOS/

# Make executable
chmod +x dist/YouTubeMini.app/Contents/MacOS/youtube-mini

echo "✅ Build complete!"
echo "📦 Your app is ready at: dist/YouTubeMini.app"

# Increment build number
echo $((BUILD_NUMBER + 1)) > BUILD_NUMBER
echo ""
echo "To share with your friend:"
echo "1. Zip the YouTubeMini.app: zip -r YouTubeMini.zip dist/YouTubeMini.app"
echo "2. Send the zip file to your friend"
echo ""
echo "Your friend will need to:"
echo "- Right-click the app and select 'Open' the first time (to bypass Gatekeeper)"
echo "- Grant Chrome automation permissions when prompted"