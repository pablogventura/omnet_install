#!/bin/bash
#
# Run all Docker tests for OMNeT++ on Ubuntu 22.04 and 24.04:
#   1. install_omnet.sh (full install + build, 15–30 min per version; skip with SKIP_INSTALL=1)
#   2. .deb package (install and opp_run; needs a built .deb)
#   3. AppImage (run and opp_run; needs a built AppImage)
#
# Each test runs on both Ubuntu 22.04 and 24.04 unless UBUNTU_VERSIONS is set (e.g. "22.04").
#
# Usage:
#   ./test_all_docker.sh
#   SKIP_INSTALL=1 ./test_all_docker.sh     # skip long install test
#   UBUNTU_VERSIONS="24.04" ./test_all_docker.sh   # only Ubuntu 24.04
#   ./test_all_docker.sh ./dist              # look for .deb and AppImage in ./dist
#
# Requires: Docker. For .deb and AppImage tests, build them first:
#   ./build_omnet_deb.sh [out_dir]
#   ./build_omnet_appimage.sh [out_dir]
#

set -e

UBUNTU_VERSIONS="${UBUNTU_VERSIONS:-22.04 24.04}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SEARCH_DIR="${1:-.}"
OMNET_VERSION="${OMNET_VERSION:-6.3.0}"
DEB_BASENAME="omnetpp_${OMNET_VERSION}-1_amd64.deb"
APPIMAGE_BASENAME="OMNeT++-${OMNET_VERSION}-x86_64.AppImage"
# Look for .deb and AppImage in SEARCH_DIR (relative to cwd) or in script dir
if [[ -d "$SEARCH_DIR" ]]; then
  DEB_PATH="$(cd "$SEARCH_DIR" 2>/dev/null && pwd)/$DEB_BASENAME"
  APPIMAGE_PATH="$(cd "$SEARCH_DIR" 2>/dev/null && pwd)/$APPIMAGE_BASENAME"
else
  DEB_PATH="$SCRIPT_DIR/$DEB_BASENAME"
  APPIMAGE_PATH="$SCRIPT_DIR/$APPIMAGE_BASENAME"
fi
[[ ! -f "$DEB_PATH" ]] && DEB_PATH="$SCRIPT_DIR/$DEB_BASENAME"
[[ ! -f "$APPIMAGE_PATH" ]] && APPIMAGE_PATH="$SCRIPT_DIR/$APPIMAGE_BASENAME"

run_test() {
  local name="$1"
  echo ""
  echo "========== $name =========="
  shift
  "$@" && echo "========== $name: OK ==========" || { echo "========== $name: FAIL =========="; return 1; }
}

FAILED=0

if [[ "${SKIP_INSTALL:-0}" != "1" ]]; then
  for UV in $UBUNTU_VERSIONS; do
    run_test "Install script (install_omnet.sh) Ubuntu $UV" "$SCRIPT_DIR/test_install_docker.sh" "$UV" || FAILED=1
  done
else
  echo ""
  echo "========== Install script: SKIPPED (SKIP_INSTALL=1) =========="
fi

if [[ -f "$DEB_PATH" ]]; then
  for UV in $UBUNTU_VERSIONS; do
    run_test ".deb package Ubuntu $UV" "$SCRIPT_DIR/test_deb_docker.sh" "$DEB_PATH" "$UV" || FAILED=1
  done
else
  echo ""
  echo "========== .deb test: SKIPPED (no .deb found, build with ./build_omnet_deb.sh) =========="
fi

if [[ -f "$APPIMAGE_PATH" ]]; then
  for UV in $UBUNTU_VERSIONS; do
    run_test "AppImage Ubuntu $UV" "$SCRIPT_DIR/test_appimage_docker.sh" "$APPIMAGE_PATH" "$UV" || FAILED=1
  done
else
  echo ""
  echo "========== AppImage test: SKIPPED (no AppImage found, build with ./build_omnet_appimage.sh) =========="
fi

echo ""
if [[ $FAILED -eq 0 ]]; then
  echo ">>> All run tests passed."
  exit 0
else
  echo ">>> Some tests failed."
  exit 1
fi
