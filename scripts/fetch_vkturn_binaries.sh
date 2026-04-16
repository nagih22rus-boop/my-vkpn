#!/usr/bin/env bash

# Downloads latest vk-turn-proxy binary and updates ALL version files.
# Single source of truth — use this before local builds AND in CI.
# Updates:
#   - android/app/src/main/jniLibs/arm64-v8a/libvkturn.so      (binary)
#   - assets/vkturn_version.txt                              (Flutter pubspec asset)
#   - android/app/src/main/assets/vkturn_version.txt         (Android native asset)
#   - assets/app_version.txt                                 (app version for update checker)
#   - android/app/src/main/assets/app_version.txt            (Android update worker)

set -euo pipefail

VKTURN_REPO="${VKTURN_REPO:-cacggghp/vk-turn-proxy}"
BASE_URL="https://github.com/$VKTURN_REPO/releases/latest/download"

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_BINARY="$ROOT_DIR/android/app/src/main/jniLibs/arm64-v8a/libvkturn.so"
OUTPUT_VKVERSION_FLUTTER="$ROOT_DIR/assets/vkturn_version.txt"
OUTPUT_VKVERSION_ANDROID="$ROOT_DIR/android/app/src/main/assets/vkturn_version.txt"
OUTPUT_APPVERSION_FLUTTER="$ROOT_DIR/assets/app_version.txt"
OUTPUT_APPVERSION_ANDROID="$ROOT_DIR/android/app/src/main/assets/app_version.txt"

echo "Fetching latest $VKTURN_REPO release info..."
VK_VERSION=$(curl -sL "https://api.github.com/repos/$VKTURN_REPO/releases/latest" \
  | grep -o '"tag_name": *"[^"]*"' \
  | head -1 \
  | cut -d'"' -f4)

if [ -z "$VK_VERSION" ]; then
  echo "Error: Failed to fetch latest version" >&2
  exit 1
fi
echo "Latest vk-turn version: $VK_VERSION"

# Read current app version from pubspec.yaml
CURRENT_APP_VERSION=$(grep "^version:" "$ROOT_DIR/pubspec.yaml" | sed 's/version: *//' | sed 's/+[0-9]*//' | tr -d ' ')
if [ -z "$CURRENT_APP_VERSION" ]; then
  echo "Error: Could not read app version from pubspec.yaml" >&2
  exit 1
fi
echo "App version: $CURRENT_APP_VERSION"

# Download vk-turn binary
mkdir -p "$(dirname "$OUTPUT_BINARY")"
echo "Downloading Android arm64 binary..."
if ! curl -fL "$BASE_URL/client-android-arm64" -o "$OUTPUT_BINARY"; then
  echo "Error: Binary download failed" >&2
  exit 1
fi
echo "Downloaded: $OUTPUT_BINARY ($(stat -f%z "$OUTPUT_BINARY") bytes)"

# Update vk-turn version files
mkdir -p "$(dirname "$OUTPUT_VKVERSION_FLUTTER")"
echo "$VK_VERSION" > "$OUTPUT_VKVERSION_FLUTTER"
echo "Updated: $OUTPUT_VKVERSION_FLUTTER"

mkdir -p "$(dirname "$OUTPUT_VKVERSION_ANDROID")"
echo "$VK_VERSION" > "$OUTPUT_VKVERSION_ANDROID"
echo "Updated: $OUTPUT_VKVERSION_ANDROID"

# Update app version files
mkdir -p "$(dirname "$OUTPUT_APPVERSION_FLUTTER")"
echo "$CURRENT_APP_VERSION" > "$OUTPUT_APPVERSION_FLUTTER"
echo "Updated: $OUTPUT_APPVERSION_FLUTTER"

mkdir -p "$(dirname "$OUTPUT_APPVERSION_ANDROID")"
echo "$CURRENT_APP_VERSION" > "$OUTPUT_APPVERSION_ANDROID"
echo "Updated: $OUTPUT_APPVERSION_ANDROID"

echo ""
echo "All done."
echo "  Binary:             $(basename "$OUTPUT_BINARY")"
echo "  vk-turn version:    $(basename "$OUTPUT_VKVERSION_FLUTTER") = $VK_VERSION"
echo "  App version:        $(basename "$OUTPUT_APPVERSION_FLUTTER") = $CURRENT_APP_VERSION"
