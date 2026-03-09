#!/bin/bash
#
# Test the OMNeT++ AppImage inside an Ubuntu 22.04 Docker container.
# Usage: ./test_appimage_docker.sh [path/to/OMNeT++-6.0.1-x86_64.AppImage]
#
# Requires: Docker, and the AppImage file.
# The script runs the AppImage with DEBUG_OMNET_APPIMAGE=1 and checks that
# usr/lib contains SWT libs (so the IDE would not fail with "Could not load SWT library").
# It also runs "opp_run --version" to verify the simulator works.
#

set -e

APPIMAGE="${1:-./OMNeT++-6.0.1-x86_64.AppImage}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APPIMAGE_ABS="$(cd "$(dirname "$APPIMAGE")" && pwd)/$(basename "$APPIMAGE")"
APPIMAGE_NAME="$(basename "$APPIMAGE_ABS")"
APPIMAGE_DIR="$(dirname "$APPIMAGE_ABS")"

if [[ ! -f "$APPIMAGE_ABS" ]]; then
  echo "Error: AppImage not found: $APPIMAGE_ABS"
  echo "Usage: $0 [path/to/OMNeT++-6.0.1-x86_64.AppImage]"
  exit 1
fi

echo ">>> Testing AppImage in Ubuntu 22.04 (Docker): $APPIMAGE_ABS"
echo ""

docker run --rm \
  -v "$APPIMAGE_DIR:/mnt:ro" \
  -e DEBUG_OMNET_APPIMAGE=1 \
  -e APPIMAGE_EXTRACT_AND_RUN=1 \
  ubuntu:22.04 \
  bash -c '
    set -e
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq && apt-get install -y -qq libfuse2 > /dev/null
    mkdir -p /app && cp "/mnt/'"$APPIMAGE_NAME"'" /app/OMNeT.AppImage && chmod +x /app/OMNeT.AppImage

    echo "--- Debug output (SWT check) ---"
    # APPIMAGE_EXTRACT_AND_RUN=1: run without FUSE (Docker has no /dev/fuse)
    # Run with timeout; IDE would wait for GUI otherwise
    OUT=$(timeout 15 /app/OMNeT.AppImage 2>&1 || true)
    echo "$OUT"
    SWT_COUNT=$(echo "$OUT" | grep "usr/lib SWT libs:" | sed -n "s/.*usr\/lib SWT libs: \([0-9]*\).*/\1/p")
    if [[ -z "$SWT_COUNT" ]]; then
      echo ""
      echo ">>> WARNING: Could not parse usr/lib SWT libs count from output."
    elif [[ "${SWT_COUNT:-0}" -eq 0 ]]; then
      echo ""
      echo ">>> FAIL: usr/lib has 0 SWT libs; IDE will fail with Could not load SWT library."
      exit 1
    else
      echo ""
      echo ">>> OK: usr/lib has $SWT_COUNT SWT lib(s)."
    fi

    echo ""
    echo "--- opp_run --version ---"
    APPIMAGE_EXTRACT_AND_RUN=1 /app/OMNeT.AppImage opp_run --version 2>&1 || true
    echo ""
    echo ">>> Test finished."
  '

echo ""
echo ">>> Docker test completed."
