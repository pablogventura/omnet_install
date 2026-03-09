#!/bin/bash
#
# Test the direct installer (install_omnet.sh) inside an Ubuntu Docker container.
# Runs the full install (download, configure, build), then checks opp_run and omnetpp.
#
# Usage: ./test_install_docker.sh [22.04|24.04]
#   Or: UBUNTU_VERSION=24.04 ./test_install_docker.sh
# Requires: Docker. Takes 15–30 minutes (download + build).
#

set -e

UBUNTU_VERSION="${UBUNTU_VERSION:-${1:-22.04}}"
case "$UBUNTU_VERSION" in 22.04|24.04) ;; *) echo "Error: UBUNTU_VERSION must be 22.04 or 24.04"; exit 1;; esac

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/install_omnet.sh"
OMNET_VERSION="${OMNET_VERSION:-6.0.1}"
OMNET_DIR="omnetpp-${OMNET_VERSION}"

if [[ ! -f "$INSTALL_SCRIPT" ]]; then
  echo "Error: install_omnet.sh not found: $INSTALL_SCRIPT"
  exit 1
fi

echo ">>> Testing install_omnet.sh in Ubuntu $UBUNTU_VERSION (Docker)"
echo ">>> This runs a full install and build (15–30 min)."
echo ""

docker run --rm \
  -v "$SCRIPT_DIR:/mnt:ro" \
  -e DEBIAN_FRONTEND=noninteractive \
  -e OMNET_VERSION="$OMNET_VERSION" \
  "ubuntu:${UBUNTU_VERSION}" \
  bash -c '
    set -e
    OMNET_VERSION="${OMNET_VERSION:-6.0.1}"
    OMNET_DIR="omnetpp-${OMNET_VERSION}"
    apt-get update -qq && apt-get install -y -qq sudo > /dev/null
    cp /mnt/install_omnet.sh /tmp/install_omnet.sh
    chmod +x /tmp/install_omnet.sh
    cd /tmp
    # Run install as root (sudo in script still works)
    bash /tmp/install_omnet.sh

    echo ""
    echo "--- Verifying installation ---"
    cd /tmp/'"$OMNET_DIR"'
    source setenv
    opp_run --version
    test -x bin/omnetpp && echo ">>> OK: bin/omnetpp exists and is executable"
    echo ""
    echo ">>> Install test finished."
  '

echo ""
echo ">>> Docker install test completed."
