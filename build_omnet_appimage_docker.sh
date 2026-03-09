#!/bin/bash
#
# Build the OMNeT++ AppImage inside an Ubuntu 22.04 container.
# This links the binary against 22.04 glibc so the AppImage runs on Ubuntu 22.04 (and 24.04).
#
# Usage: ./build_omnet_appimage_docker.sh [output_directory]
#   Default: AppImage is written to the current directory.
#
# Requires: Docker. First run takes ~20–40 min (image, deps, build and linuxdeploy).
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="${1:-$SCRIPT_DIR}"
OUTPUT_ABS="$(cd "$(dirname "$OUTPUT_DIR")" && pwd)/$(basename "$OUTPUT_DIR")"
OMNET_VERSION="${OMNET_VERSION:-6.3.0}"
APPIMAGE_NAME="OMNeT++-${OMNET_VERSION}-x86_64.AppImage"

echo ">>> Building OMNeT++ AppImage in Docker (Ubuntu 22.04)"
echo ">>> Output: $OUTPUT_ABS"
echo ""

docker run --rm \
  -v "$SCRIPT_DIR:/mnt:ro" \
  -v "$OUTPUT_ABS:/output" \
  -e DEBIAN_FRONTEND=noninteractive \
  -e OMNET_VERSION="$OMNET_VERSION" \
  -e APPIMAGE_EXTRACT_AND_RUN=1 \
  ubuntu:22.04 \
  bash -c '
    set -e
    echo ">>> Installing build dependencies..."
    apt-get update -qq
    apt-get install -y -qq \
      build-essential clang lld gdb bison flex perl \
      python3 python3-pip python3-venv \
      qtbase5-dev qtchooser qt5-qmake qtbase5-dev-tools \
      libqt5opengl5-dev libxml2-dev zlib1g-dev doxygen graphviz xdg-utils \
      python3-numpy python3-scipy python3-matplotlib python3-pandas python3-seaborn \
      mpi-default-dev libstdc++-12-dev \
      wget libfuse2 unzip > /dev/null
    apt-get install -y -qq libwebkit2gtk-4.0-37 2>/dev/null || true

    echo ">>> Running build_omnet_appimage.sh (output in /output)..."
    /mnt/build_omnet_appimage.sh /output
    echo ""
    echo ">>> AppImage generated in /output (mounted on host)."
  '

echo ""
echo ">>> Done. AppImage: $OUTPUT_ABS/$APPIMAGE_NAME"
echo ">>> Test on 22.04 and 24.04: SKIP_INSTALL=1 ./test_all_docker.sh"
echo ""
