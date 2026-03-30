#!/bin/bash
set -e

export PATH="$PATH:/usr/local/go/bin:/opt/homebrew/bin:/usr/local/bin"

ACTION="$1"

C1="$BUILD_DIR/../../SourcePackages/checkouts/wireguard-apple/Sources/WireGuardKitGo"
C2="$BUILD_DIR/../../../SourcePackages/checkouts/wireguard-apple/Sources/WireGuardKitGo"
C3="$SYMROOT/../../SourcePackages/checkouts/wireguard-apple/Sources/WireGuardKitGo"

if [ -d "$C1" ]; then
  TARGET_DIR="$C1"
elif [ -d "$C2" ]; then
  TARGET_DIR="$C2"
elif [ -d "$C3" ]; then
  TARGET_DIR="$C3"
else
  echo "error: WireGuardKitGo directory not found"
  exit 1
fi

cd "$TARGET_DIR"
if [ "$ACTION" == "build" ] || [ -z "$ACTION" ]; then
  /usr/bin/make
else
  /usr/bin/make "$ACTION"
fi
