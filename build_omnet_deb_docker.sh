#!/bin/bash
#
# Build the OMNeT++ .deb package inside an Ubuntu 22.04 container.
# This links the package against 22.04 glibc so it runs on both 22.04 and 24.04.
#
# Usage: ./build_omnet_deb_docker.sh [output_directory]
#   Default: .deb is written to the current directory.
#
# Requires: Docker. First run takes ~15–30 min (image download, deps and build).
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="${1:-$SCRIPT_DIR}"
OUTPUT_ABS="$(cd "$(dirname "$OUTPUT_DIR")" && pwd)/$(basename "$OUTPUT_DIR")"
OMNET_VERSION="${OMNET_VERSION:-6.3.0}"
DEB_NAME="omnetpp_${OMNET_VERSION}-1_amd64.deb"

echo ">>> Building OMNeT++ .deb in Docker (Ubuntu 22.04)"
echo ">>> Output: $OUTPUT_ABS"
echo ""

docker run --rm \
  -v "$SCRIPT_DIR:/mnt:ro" \
  -v "$OUTPUT_ABS:/output" \
  -e DEBIAN_FRONTEND=noninteractive \
  -e OMNET_VERSION="$OMNET_VERSION" \
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
      wget dpkg-dev > /dev/null
    apt-get install -y -qq libwebkit2gtk-4.0-37 2>/dev/null || true

    echo ">>> Running build_omnet_deb.sh in /output..."
    /mnt/build_omnet_deb.sh /output
    echo ""
    echo ">>> .deb generated in /output (mounted on host)."
  '

echo ""
echo ">>> Done. Package: $OUTPUT_ABS/$DEB_NAME"
echo ">>> Test on 22.04 and 24.04: SKIP_INSTALL=1 ./test_all_docker.sh"
echo ""
