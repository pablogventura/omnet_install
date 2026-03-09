#!/bin/bash
#
# Test OMNeT++ with GUI in two ways:
#
#   --x11       Use your machine's display (X11). The OMNeT++ window opens on your desktop.
#               Requires: xhost +local:docker (once) and DISPLAY on the host.
#
#   --browser   Start a desktop in a container and serve it via noVNC. Open http://localhost:6901
#               in the browser to see the desktop; open a terminal and run OMNeT++ to verify the IDE loads.
#
#   --browser-check  Same as --browser but runs an automatic check: launches the IDE in the container,
#                    waits and checks with wmctrl if a window with "OMNeT" appeared. Useful for CI.
#
# Usage:
#   ./test_gui_docker.sh --x11 [path/to/AppImage]
#   ./test_gui_docker.sh --browser [path/to/AppImage]
#   ./test_gui_docker.sh --browser-check [path/to/AppImage]
#   ./test_gui_docker.sh --browser .deb [path/to/package.deb]
#
# Default: AppImage in current directory (OMNeT++-6.0.1-x86_64.AppImage).
# Requires: Docker. For --browser/--browser-check the image accetto/ubuntu-vnc-xfce-g3 is used.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODE=""
TYPE="appimage"
FILE_ARG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --x11|--browser|--browser-check)
      MODE="$1"
      shift
      ;;
    .deb)
      TYPE="deb"
      shift
      ;;
    *)
      FILE_ARG="$1"
      shift
      ;;
  esac
done

if [[ -z "$MODE" ]]; then
  echo "Usage: $0 --x11 | --browser | --browser-check [.deb] [path/to/file]"
  echo ""
  echo "  --x11           Window on your screen (X11 forwarding)"
  echo "  --browser       Desktop at http://localhost:6901 (noVNC); open browser and run OMNeT++"
  echo "  --browser-check Same as --browser but script checks if OMNeT++ window appeared"
  echo ""
  echo "Examples:"
  echo "  $0 --browser ./OMNeT++-6.0.1-x86_64.AppImage"
  echo "  $0 --browser-check"
  echo "  $0 --browser .deb ./omnetpp_6.0.1-1_amd64.deb"
  exit 1
fi

if [[ "$TYPE" == "deb" ]]; then
  OMNET_VERSION="${OMNET_VERSION:-6.0.1}"
  DEB="${FILE_ARG:-$SCRIPT_DIR/omnetpp_${OMNET_VERSION}-1_amd64.deb}"
  DEB_ABS="$(cd "$(dirname "$DEB")" && pwd)/$(basename "$DEB")"
  DEB_DIR="$(dirname "$DEB_ABS")"
  DEB_NAME="$(basename "$DEB_ABS")"
  if [[ ! -f "$DEB_ABS" ]]; then
    echo "Error: .deb not found: $DEB_ABS"
    exit 1
  fi
  APPIMAGE_ABS=""
else
  OMNET_VERSION="${OMNET_VERSION:-6.0.1}"
  APPIMAGE="${FILE_ARG:-$SCRIPT_DIR/OMNeT++-${OMNET_VERSION}-x86_64.AppImage}"
  APPIMAGE_ABS="$(cd "$(dirname "$APPIMAGE")" && pwd)/$(basename "$APPIMAGE")"
  if [[ ! -f "$APPIMAGE_ABS" ]]; then
    echo "Error: AppImage not found: $APPIMAGE_ABS"
    exit 1
  fi
  APPIMAGE_NAME="$(basename "$APPIMAGE_ABS")"
  APPIMAGE_DIR="$(dirname "$APPIMAGE_ABS")"
fi

# --- X11 mode: window on host
run_x11() {
  if [[ -z "$DISPLAY" ]]; then
    echo "Error: DISPLAY is not set. Run this script in a session with a display (X11 or Wayland+Xwayland)."
    exit 1
  fi
  echo ">>> X11 mode: OMNeT++ window will open on your screen."
  echo ">>> If it fails, try on the host: xhost +local:docker"
  echo ""
  if [[ -n "$APPIMAGE_ABS" ]]; then
    docker run --rm -it \
      -e DISPLAY="$DISPLAY" \
      -e APPIMAGE_EXTRACT_AND_RUN=1 \
      -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
      -v "$APPIMAGE_DIR:/mnt:ro" \
      ubuntu:22.04 \
      bash -c '
        apt-get update -qq && apt-get install -y -qq libfuse2 libgtk-3-0 libxtst6 libxi6 libxrender1 libxfixes3 > /dev/null
        chmod +x "/mnt/'"$(basename "$APPIMAGE_ABS")"'"
        echo "Opening OMNeT++..."
        exec "/mnt/'"$(basename "$APPIMAGE_ABS")"'"
      '
  else
    echo "X11 mode with .deb: install .deb in container and run omnetpp (requires more dependencies)."
    echo "Recommendation: use --browser with .deb to test the IDE."
    exit 1
  fi
}

# --- Browser mode (noVNC): desktop at http://localhost:6901
# In accetto/ubuntu-vnc-xfce-g3 user headless has $HOME=/home/headless; Desktop may be there
NOVNC_IMAGE="${NOVNC_IMAGE:-accetto/ubuntu-vnc-xfce-g3}"
NOVNC_PORT="${NOVNC_PORT:-6901}"
CONTAINER_NAME="omnet-gui-test-$$"
DESKTOP_DIR="/home/headless/Desktop"

run_browser() {
  echo ">>> Starting desktop with noVNC (image: $NOVNC_IMAGE)"
  echo ">>> Open in browser: http://localhost:$NOVNC_PORT"
  echo ">>> Default password: headless (user headless)."
  echo ""
  if [[ -n "$APPIMAGE_ABS" ]]; then
    docker run -d --name "$CONTAINER_NAME" \
      -p "${NOVNC_PORT}:6901" \
      -e VNC_PW=headless \
      -v "$APPIMAGE_DIR:/opt/mnt:ro" \
      "$NOVNC_IMAGE" \
      > /dev/null
    docker exec "$CONTAINER_NAME" bash -c "
      chmod +x /opt/mnt/$(basename "$APPIMAGE_ABS") 2>/dev/null || true
      mkdir -p $DESKTOP_DIR
      echo '#!/bin/bash' > $DESKTOP_DIR/run-omnetpp.sh
      echo 'export APPIMAGE_EXTRACT_AND_RUN=1' >> $DESKTOP_DIR/run-omnetpp.sh
      echo 'exec /opt/mnt/$(basename "$APPIMAGE_ABS")' >> $DESKTOP_DIR/run-omnetpp.sh
      chmod +x $DESKTOP_DIR/run-omnetpp.sh
      chown headless:headless $DESKTOP_DIR/run-omnetpp.sh 2>/dev/null || true
    "
    echo ">>> On desktop: double-click 'run-omnetpp.sh' or in a terminal: APPIMAGE_EXTRACT_AND_RUN=1 /opt/mnt/$(basename "$APPIMAGE_ABS")"
  else
    docker run -d --name "$CONTAINER_NAME" \
      -p "${NOVNC_PORT}:6901" \
      -e VNC_PW=headless \
      -v "$DEB_DIR:/mnt/deb:ro" \
      "$NOVNC_IMAGE" \
      > /dev/null
    docker exec "$CONTAINER_NAME" bash -c "
      apt-get update -qq && apt-get install -y -qq dpkg apt-utils > /dev/null
      dpkg -i /mnt/deb/$DEB_NAME || true
      apt-get install -f -y -qq
      mkdir -p $DESKTOP_DIR
      echo '#!/bin/bash' > $DESKTOP_DIR/run-omnetpp.sh
      echo 'exec omnetpp' >> $DESKTOP_DIR/run-omnetpp.sh
      chmod +x $DESKTOP_DIR/run-omnetpp.sh
      chown headless:headless $DESKTOP_DIR/run-omnetpp.sh 2>/dev/null || true
    " 2>/dev/null
    echo ">>> On desktop: double-click 'run-omnetpp.sh' or in a terminal: omnetpp"
  fi
  echo ""
  echo ">>> Container: $CONTAINER_NAME. To stop: docker stop $CONTAINER_NAME"
  echo ""
  echo "Open http://localhost:$NOVNC_PORT and verify OMNeT++ starts."
}

# --- Browser-check mode: same as browser but runs automatic check with wmctrl
run_browser_check() {
  run_browser
  echo ">>> Waiting 5 s for desktop to be ready..."
  sleep 5
  echo ">>> Installing wmctrl and launching OMNeT++ in container..."
  if [[ -n "$APPIMAGE_ABS" ]]; then
    APPIMAGE_BASENAME="$(basename "$APPIMAGE_ABS")"
    docker exec "$CONTAINER_NAME" bash -c "
      apt-get update -qq && apt-get install -y -qq wmctrl > /dev/null
      sudo -u headless env DISPLAY=:1 APPIMAGE_EXTRACT_AND_RUN=1 /opt/mnt/$APPIMAGE_BASENAME &
    " 2>/dev/null || true
  else
    docker exec "$CONTAINER_NAME" bash -c "
      apt-get update -qq && apt-get install -y -qq wmctrl > /dev/null
      sudo -u headless env DISPLAY=:1 omnetpp &
    " 2>/dev/null || true
  fi
  echo ">>> Waiting 30 s for OMNeT++ window to appear..."
  sleep 30
  FOUND=$(docker exec "$CONTAINER_NAME" bash -c "DISPLAY=:1 wmctrl -l 2>/dev/null | grep -i omnet || true") || true
  docker stop "$CONTAINER_NAME" > /dev/null 2>&1 || true
  docker rm "$CONTAINER_NAME" > /dev/null 2>&1 || true
  if [[ -n "$FOUND" ]]; then
    echo ">>> OK: OMNeT++ window detected on desktop."
    echo "$FOUND"
    exit 0
  else
    echo ">>> FAIL: No window with 'OMNeT' in title found (wmctrl -l)."
    echo ">>> Use --browser (without -check) and open http://localhost:$NOVNC_PORT to verify manually."
    exit 1
  fi
}

case "$MODE" in
  --x11)    run_x11 ;;
  --browser) run_browser ;;
  --browser-check) run_browser_check ;;
  *) echo "Mode not implemented: $MODE"; exit 1 ;;
esac
