#!/usr/bin/env bash

# Downloads latest vk-turn-proxy binary and updates ALL version files.
# Single source of truth — use this before local builds AND in CI.
# Updates:
#   - android/app/src/main/jniLibs/arm64-v8a/libvkturn.so  (binary)
#   - assets/vkturn_version.txt                            (Flutter pubspec asset)
#   - android/app/src/main/assets/vkturn_version.txt       (Android native asset)

set -euo pipefail

VKTURN_REPO="${VKTURN_REPO:-cacggghp/vk-turn-proxy}"
BASE_URL="https://github.com/$VKTURN_REPO/releases/latest/download"

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_BINARY="$ROOT_DIR/android/app/src/main/jniLibs/arm64-v8a/libvkturn.so"
OUTPUT_VERSION_FLUTTER="$ROOT_DIR/assets/vkturn_version.txt"
OUTPUT_VERSION_ANDROID="$ROOT_DIR/android/app/src/main/assets/vkturn_version.txt"

echo "Fetching latest $VKTURN_REPO release info..."
VK_VERSION=$(curl -sL "https://api.github.com/repos/$VKTURN_REPO/releases/latest" \
  | grep -o '"tag_name": *"[^"]*"' \
  | head -1 \
  | cut -d'"' -f4)

if [ -z "$VK_VERSION" ]; then
  echo "Error: Failed to fetch latest version" >&2
  exit 1
fi

echo "Latest version: $VK_VERSION"

# Download binary
mkdir -p "$(dirname "$OUTPUT_BINARY")"
echo "Downloading Android arm64 binary..."
if ! curl -fL "$BASE_URL/client-android-arm64" -o "$OUTPUT_BINARY"; then
  echo "Error: Binary download failed" >&2
  exit 1
fi
echo "Downloaded: $OUTPUT_BINARY ($(stat -f%z "$OUTPUT_BINARY") bytes)"

# Update version file in Flutter assets (pubspec.yaml includes assets/vkturn_version.txt)
mkdir -p "$(dirname "$OUTPUT_VERSION_FLUTTER")"
echo "$VK_VERSION" > "$OUTPUT_VERSION_FLUTTER"
echo "Updated: $OUTPUT_VERSION_FLUTTER"

# Update version file in Android native assets (read by VkTurnProcessManager.getVersion())
mkdir -p "$(dirname "$OUTPUT_VERSION_ANDROID")"
echo "$VK_VERSION" > "$OUTPUT_VERSION_ANDROID"
echo "Updated: $OUTPUT_VERSION_ANDROID"

echo ""
echo "All done."
echo "  Binary:        $(basename "$OUTPUT_BINARY")"
echo "  Flutter asset: $(basename "$OUTPUT_VERSION_FLUTTER") = $VK_VERSION"
echo "  Android asset: $(basename "$OUTPUT_VERSION_ANDROID") = $VK_VERSION"
