#!/bin/bash
set -euo pipefail

APP_NAME="Lyrics"

echo "🚧 Building..."
swift build

BUILD_DIR="$(swift build --show-bin-path)"
BUNDLE_APP="$BUILD_DIR/$APP_NAME.app"

if [ ! -d "$BUNDLE_APP" ]; then
    echo "⚠️ SwiftPM did not emit $APP_NAME.app, falling back to manual bundling..."

    CONTENTS_DIR="$BUNDLE_APP/Contents"
    MACOS_DIR="$CONTENTS_DIR/MacOS"
    RESOURCES_DIR="$CONTENTS_DIR/Resources"
    RESOURCE_BUNDLE="$BUILD_DIR/${APP_NAME}_${APP_NAME}.bundle"

    rm -rf "$BUNDLE_APP"
    mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

    cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/"
    cp "Lyrics/Info.plist" "$CONTENTS_DIR/Info.plist"

    if [ -d "$RESOURCE_BUNDLE" ]; then
        cp -R "$RESOURCE_BUNDLE" "$RESOURCES_DIR/"
    fi

    # Ensure the app bundle contains compiled icon metadata for Finder/Dock.
    xcrun actool "Lyrics/Assets.xcassets" \
        --compile "$RESOURCES_DIR" \
        --platform macosx \
        --minimum-deployment-target 13.0 \
        --app-icon AppIcon \
        --output-partial-info-plist "/tmp/${APP_NAME}_assetcatalog_generated_info.plist" || true
        
    # Copy the manual .icns icon if actool fails or fails to bundle it properly
    if [ -f "Lyrics/AppIcon.icns" ]; then
        cp "Lyrics/AppIcon.icns" "$RESOURCES_DIR/"
    fi
fi

echo "🔑 Signing..."
codesign --force --deep --sign - --entitlements "Lyrics/Lyrics.entitlements" "$BUNDLE_APP"

echo "🚀 Launching..."
open "$BUNDLE_APP"
