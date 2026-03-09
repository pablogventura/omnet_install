#!/bin/bash
#
# Test installing and running the OMNeT++ .deb package inside an Ubuntu Docker container.
# Installs the .deb, fixes dependencies if needed, then checks opp_run and omnetpp in PATH.
#
# Usage: ./test_deb_docker.sh [path/to/omnetpp_6.0.1-1_amd64.deb] [22.04|24.04]
#   Or: UBUNTU_VERSION=24.04 ./test_deb_docker.sh [path/to.deb]
# Default: ./omnetpp_6.0.1-1_amd64.deb, Ubuntu 22.04
# Requires: Docker, and a built .deb (e.g. from ./build_omnet_deb.sh).
#

set -e

OMNET_VERSION="${OMNET_VERSION:-6.0.1}"
DEB="${1:-./omnetpp_${OMNET_VERSION}-1_amd64.deb}"
UBUNTU_VERSION="${UBUNTU_VERSION:-${2:-22.04}}"
case "$UBUNTU_VERSION" in 22.04|24.04) ;; *) echo "Error: UBUNTU_VERSION must be 22.04 or 24.04"; exit 1;; esac

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEB_ABS="$(cd "$(dirname "$DEB")" && pwd)/$(basename "$DEB")"
DEB_DIR="$(dirname "$DEB_ABS")"
DEB_NAME="$(basename "$DEB_ABS")"

if [[ ! -f "$DEB_ABS" ]]; then
  echo "Error: .deb not found: $DEB_ABS"
  echo "Build it first: ./build_omnet_deb.sh"
  echo "Usage: $0 [path/to/omnetpp_${OMNET_VERSION}-1_amd64.deb] [22.04|24.04]"
  exit 1
fi

echo ">>> Testing .deb in Ubuntu $UBUNTU_VERSION (Docker): $DEB_ABS"
echo ""

docker run --rm \
  -v "$DEB_DIR:/mnt:ro" \
  -e DEBIAN_FRONTEND=noninteractive \
  "ubuntu:${UBUNTU_VERSION}" \
  bash -c '
    set -e
    apt-get update -qq && apt-get install -y -qq dpkg apt-utils > /dev/null
    dpkg -i "/mnt/'"$DEB_NAME"'" || true
    apt-get install -f -y -qq
    echo ""
    echo "--- PATH and binaries ---"
    which opp_run && which omnetpp && echo ">>> OK: opp_run and omnetpp in PATH"
    echo ""
    echo "--- opp_run --version ---"
    OUT=$(opp_run --version 2>&1) || true
    echo "$OUT"
    if echo "$OUT" | grep -q "OMNeT++" && echo "$OUT" | grep -q "Version:"; then
      echo ">>> OK: opp_run runs and prints version"
    else
      echo ">>> FAIL: opp_run did not print version (glibc/abi mismatch?)"
      exit 1
    fi
    echo ""
    echo ">>> .deb test finished."
  '

echo ""
echo ">>> Docker .deb test completed."
