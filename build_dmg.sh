#!/bin/bash
set -e

PROJECT="DropShelf.xcodeproj"
SCHEME="DropShelf"
APP_NAME="DropShelf"
BUILD_DIR="$(pwd)/build"
DMG_DIR="$(pwd)/dist"

echo "==> Cleaning build folder..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$DMG_DIR"

echo "==> Building Release..."
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    build

APP_PATH=$(find "$BUILD_DIR" -name "${APP_NAME}.app" -not -path "*/Index.noindex/*" | head -1)

if [ -z "$APP_PATH" ]; then
    echo "ERROR: ${APP_NAME}.app not found in build output"
    exit 1
fi

echo "==> Found app: $APP_PATH"

# Собираем версию из Info.plist
VERSION=$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "1.0")
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_PATH="$DMG_DIR/$DMG_NAME"
TMP_DMG="$BUILD_DIR/tmp.dmg"
VOLUME_NAME="$APP_NAME"

echo "==> Creating DMG: $DMG_NAME"

# Временный DMG с нужным размером
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$APP_PATH" \
    -ov \
    -format UDRW \
    "$TMP_DMG"

# Монтируем для добавления симлинки на Applications
MOUNT_DIR=$(hdiutil attach "$TMP_DMG" | grep "/Volumes/" | awk '{print $NF}')
ln -sf /Applications "$MOUNT_DIR/Applications"
hdiutil detach "$MOUNT_DIR" -quiet

# Финальный сжатый DMG
hdiutil convert "$TMP_DMG" -format UDZO -o "$DMG_PATH" -ov

rm -f "$TMP_DMG"

echo ""
echo "==> Done: dist/$DMG_NAME"
