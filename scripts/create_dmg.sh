#!/bin/bash
set -e

DMG_NAME="${1:-Lumos.dmg}"
APP="export/Lumos.app"
VOLUME_NAME="Lumos"
TMP_DMG="tmp_${DMG_NAME}"

echo "Creating DMG: $DMG_NAME"

# Create writable temp DMG
hdiutil create \
  -srcfolder "$APP" \
  -volname "$VOLUME_NAME" \
  -fs HFS+ \
  -fsargs "-c c=64,a=16,b=16" \
  -format UDRW \
  -size 150m \
  "$TMP_DMG"

# Mount
DEVICE=$(hdiutil attach -readwrite -noverify "$TMP_DMG" | grep '/dev/disk' | head -1 | awk '{print $1}')
sleep 2

# Add Applications symlink for drag-to-install
ln -s /Applications "/Volumes/$VOLUME_NAME/Applications"

# Detach
hdiutil detach "$DEVICE"
sleep 1

# Convert to compressed read-only DMG
hdiutil convert "$TMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_NAME"
rm "$TMP_DMG"

echo "Done: $DMG_NAME"
