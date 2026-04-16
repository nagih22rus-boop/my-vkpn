#!/usr/bin/env bash

set -euo pipefail

# Downloads latest vk-turn-proxy Android binary from cacggghp/vk-turn-proxy

BASE_URL="https://github.com/cacggghp/vk-turn-proxy/releases/latest/download"
OUTPUT_DIR="android/app/src/main/jniLibs/arm64-v8a"

echo "Fetching latest vk-turn-proxy release info..."
VK_VERSION=$(curl -sL "https://api.github.com/repos/cacggghp/vk-turn-proxy/releases/latest" \
  | grep -o '"tag_name": *"[^"]*"' \
  | head -1 \
  | cut -d'"' -f4)

if [ -z "$VK_VERSION" ]; then
  echo "Failed to fetch latest version" >&2
  exit 1
fi

echo "Latest version: $VK_VERSION"

mkdir -p "$OUTPUT_DIR"

echo "Downloading Android arm64 binary..."
if ! curl -fL "$BASE_URL/client-android-arm64" -o "$OUTPUT_DIR/libvkturn.so"; then
  echo "Download failed" >&2
  exit 1
fi

echo "$VK_VERSION" > assets/vkturn_version.txt

echo "Done. Binary: $OUTPUT_DIR/libvkturn.so ($(stat -c%s "$OUTPUT_DIR/libvkturn.so") bytes)"
echo "Version: $VK_VERSION"
