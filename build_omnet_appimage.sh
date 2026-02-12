#!/bin/bash
#
# Script to build a portable AppImage of OMNeT++ 6.0.1
# Usage: ./build_omnet_appimage.sh [output_directory]
#
# Requirements: wget, tar, OMNeT++ build dependencies (optional -d).
# Creates an AppDir and uses appimagetool (downloaded if missing) to create the .AppImage.
#
# Bundles dependencies (Qt5, system libs) via linuxdeploy + Qt plugin so no
# packages need to be installed on Ubuntu. Python3 and venv remain in the OMNeT++ tree.
#

set -e

OMNET_VERSION="${OMNET_VERSION:-6.0.1}"
OMNET_TARBALL="omnetpp-${OMNET_VERSION}-linux-x86_64.tgz"
OMNET_URL="https://github.com/omnetpp/omnetpp/releases/download/omnetpp-${OMNET_VERSION}/${OMNET_TARBALL}"
INSTALL_PREFIX="/opt/omnetpp-${OMNET_VERSION}"
OUTPUT_DIR="."
BUILD_DIR="${BUILD_DIR:-$(mktemp -d)}"
APPIMAGE_NAME="OMNeT++-${OMNET_VERSION}-x86_64.AppImage"
APPIMAGETOOL_URL="https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
LINUXDEPLOY_URL="https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage"
LINUXDEPLOY_PLUGIN_QT_URL="https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage"

# Install build dependencies only (optional)
install_build_deps() {
    echo ">>> Installing build dependencies..."
    sudo apt-get update
    sudo apt-get -y install build-essential clang lld gdb bison flex perl \
        python3 python3-pip python3-venv qtbase5-dev qtchooser qt5-qmake qtbase5-dev-tools \
        libqt5opengl5-dev libxml2-dev zlib1g-dev doxygen graphviz xdg-utils \
        python3-numpy python3-scipy python3-matplotlib python3-pandas python3-seaborn \
        mpi-default-dev libstdc++-12-dev
    sudo apt-get -y install libwebkit2gtk-4.1-0 2>/dev/null \
        || sudo apt-get -y install libwebkit2gtk-4.0-37 2>/dev/null \
        || echo ">>> Warning: libwebkit2gtk not installed (optional for the IDE)"
}

usage() {
    echo "Usage: $0 [OPTIONS] [output_directory]"
    echo ""
    echo "Builds an OMNeT++ ${OMNET_VERSION} AppImage."
    echo ""
    echo "  -d, --install-deps   Install build dependencies before building"
    echo "  -h, --help            Show this help"
    echo ""
    echo "  output_directory     Folder where the .AppImage will be saved (default: .)"
    echo ""
    echo "Environment variables:"
    echo "  OMNET_VERSION        OMNeT++ version (default: ${OMNET_VERSION})"
    echo "  BUILD_DIR            Build directory (default: temporary). If you set it"
    echo "                       (e.g. BUILD_DIR=./build) and run again, the build is reused."
}

INSTALL_DEPS=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--install-deps)
            INSTALL_DEPS=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
        *)
            OUTPUT_DIR="$1"
            shift
            ;;
    esac
done

if [[ "$INSTALL_DEPS" == true ]]; then
    install_build_deps
fi

check_build_tools() {
    local missing=()
    command -v bison >/dev/null 2>&1 || missing+=(bison)
    command -v flex  >/dev/null 2>&1 || missing+=(flex)
    command -v g++   >/dev/null 2>&1 || missing+=(g++)
    command -v make  >/dev/null 2>&1 || missing+=(make)
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo ">>> Error: missing build tools: ${missing[*]}"
        echo ">>> Install with: $0 -d"
        exit 1
    fi
}
check_build_tools

mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
mkdir -p "$BUILD_DIR"
BUILD_DIR="$(cd "$BUILD_DIR" && pwd)"

echo ">>> Build directory: $BUILD_DIR"
echo ">>> AppImage output: $OUTPUT_DIR"
echo ">>> Version: $OMNET_VERSION"
echo ">>> (To reuse this build: BUILD_DIR=$BUILD_DIR $0)"
echo ""

SRC_DIR="$BUILD_DIR/omnetpp-${OMNET_VERSION}"
APPDIR="$BUILD_DIR/OMNeT++.AppDir"
ROOT="$APPDIR${INSTALL_PREFIX}"
REUSE_BUILD=false
[[ -x "$SRC_DIR/bin/opp_run" ]] && REUSE_BUILD=true

if [[ "$REUSE_BUILD" == true ]]; then
  echo ">>> Reusing existing build in $SRC_DIR"
else
  # Download OMNeT++
  if [[ ! -f "$BUILD_DIR/$OMNET_TARBALL" ]]; then
    echo ">>> Downloading $OMNET_URL ..."
    wget -c -O "$BUILD_DIR/$OMNET_TARBALL" "$OMNET_URL"
  else
    echo ">>> Using existing tarball: $BUILD_DIR/$OMNET_TARBALL"
  fi

  echo ">>> Extracting..."
  tar xzf "$BUILD_DIR/$OMNET_TARBALL" -C "$BUILD_DIR"

  # Venv and Python dependencies for the build
  echo ">>> Creating venv and Python dependencies for the build..."
  python3 -m venv "$SRC_DIR/venv"
  "$SRC_DIR/venv/bin/pip" install --upgrade pip -q
  "$SRC_DIR/venv/bin/pip" install numpy pandas matplotlib scipy seaborn posix_ipc -q

  # Build OMNeT++
  echo ">>> Configuring and building OMNeT++..."
  cd "$SRC_DIR"
  source setenv 2>/dev/null || true
  export PATH="$SRC_DIR/venv/bin:$PATH"
  export VIRTUAL_ENV="$SRC_DIR/venv"
  sed -i 's/WITH_OSG=yes/WITH_OSG=no/' configure.user
  ./configure --prefix="$INSTALL_PREFIX"
  NPROC=$(nproc)
  echo ">>> Building with $NPROC threads..."
  make -j"$NPROC"
fi

mkdir -p "$APPDIR"

# Copy tree to AppDir
echo ">>> Copying build tree to AppDir..."
mkdir -p "$ROOT"
cp -a "$SRC_DIR"/* "$ROOT/"

# Replace build paths with install path
echo ">>> Fixing paths in configuration files..."
OMNET_VER_SED="${OMNET_VERSION//./\\.}"
SED_TMP_PATTERN="/tmp/tmp\.[^/]*/omnetpp-${OMNET_VER_SED}"
replace_build_path() {
  sed -i "s|${SED_TMP_PATTERN}|${INSTALL_PREFIX}|g" "$1" 2>/dev/null || true
  sed -i "s|${SRC_DIR}|${INSTALL_PREFIX}|g" "$1" 2>/dev/null || true
}
while IFS= read -r -d '' f; do
  replace_build_path "$f"
done < <(find "$ROOT" -type f \( -name "*.ini" -o -name "*.properties" -o -name "*.xml" -o -name "*.cfg" -o -name "*.conf" -o -name "*.user" -o -name "*.launch" -o -name "*.prefs" -o -name "*.product" -o -name "config.ini" \) ! -path "*/venv/*" -print0 2>/dev/null)
[[ -d "$ROOT/ide" ]] && find "$ROOT/ide" -type f ! -path "*/venv/*" 2>/dev/null | while read -r f; do
  case "$(file -b --mime-type "$f" 2>/dev/null)" in text/*) replace_build_path "$f" ;; esac
done
while IFS= read -r -d '' f; do
  [[ "$f" == *"/venv/"* ]] && continue
  case "$(file -b --mime-type "$f" 2>/dev/null)" in text/*) replace_build_path "$f" ;; esac
done < <(grep -rZl --fixed-strings "/tmp/tmp." "$ROOT" 2>/dev/null)
[[ -f "$ROOT/setenv" ]] && chmod +x "$ROOT/setenv"
[[ -d "$ROOT/bin" ]] && chmod +x "$ROOT/bin"/* 2>/dev/null || true

# Venv in the AppDir
echo ">>> Configuring Python environment (venv) in the AppDir..."
python3 -m venv "$ROOT/venv"
"$ROOT/venv/bin/pip" install --upgrade pip -q
"$ROOT/venv/bin/pip" install numpy pandas matplotlib scipy seaborn posix_ipc -q

# AppRun, icon and .desktop before linuxdeploy (avoids WARNING and allows integration)
echo ">>> Creating AppRun, icon and .desktop..."
cat > "$APPDIR/AppRun" << 'APPRUN'
#!/bin/bash
set -e
APPDIR="$(dirname "$(readlink -f "$0")")"
# Bundled libraries (Qt5, etc.) in the AppImage
export LD_LIBRARY_PATH="${APPDIR}/usr/lib:${APPDIR}/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH}"
READONLY_ROOT="${APPDIR}/opt/omnetpp-6.0.1"
WRITABLE_BASE="${XDG_DATA_HOME:-$HOME/.local/share}"
WRITABLE_OMNET="${WRITABLE_BASE}/omnetpp-6.0.1"

# opp_run does not write to ide/; can run from read-only mount
if [[ "${1:-}" == "opp_run" ]] || [[ "${1:-}" == "run" ]]; then
  export OMNETPP_ROOT="$READONLY_ROOT"
  export PATH="${OMNETPP_ROOT}/bin:${PATH}"
  exec "${OMNETPP_ROOT}/bin/opp_run" "${@:2}"
fi

# IDE: needs to write to ide/ (error.log, workspace, etc.) -> use writable copy
if [[ ! -d "$WRITABLE_OMNET/bin" ]]; then
  echo "First run: copying OMNeT++ to ${WRITABLE_OMNET} (this may take a moment)..."
  mkdir -p "$WRITABLE_OMNET"
  cp -a "$READONLY_ROOT"/* "$WRITABLE_OMNET/"
fi
export OMNETPP_ROOT="$WRITABLE_OMNET"
export PATH="${OMNETPP_ROOT}/bin:${PATH}"
exec "${OMNETPP_ROOT}/bin/omnetpp" "$@"
APPRUN
sed -i "s|omnetpp-6\.0\.1|omnetpp-${OMNET_VERSION}|g" "$APPDIR/AppRun"
chmod +x "$APPDIR/AppRun"

OMNET_ICON_SRC=""
[[ -f "$ROOT/images/logo/logo128.png" ]] && OMNET_ICON_SRC="$ROOT/images/logo/logo128.png"
[[ -z "$OMNET_ICON_SRC" ]] && [[ -f "$ROOT/images/logo/logo128s.png" ]] && OMNET_ICON_SRC="$ROOT/images/logo/logo128s.png"
[[ -z "$OMNET_ICON_SRC" ]] && [[ -f "$ROOT/ide/icon.png" ]] && OMNET_ICON_SRC="$ROOT/ide/icon.png"
[[ -z "$OMNET_ICON_SRC" ]] && [[ -f "$ROOT/ide/omnetpp.png" ]] && OMNET_ICON_SRC="$ROOT/ide/omnetpp.png"
if [[ -n "$OMNET_ICON_SRC" ]]; then
  cp "$OMNET_ICON_SRC" "$APPDIR/omnetpp.png"
  cp "$OMNET_ICON_SRC" "$APPDIR/.DirIcon"
fi

cat > "$APPDIR/omnetpp.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=OMNeT++ ${OMNET_VERSION} IDE
Comment=OMNeT++ Discrete Event Simulation IDE
Exec=AppRun
Icon=omnetpp
Terminal=false
Categories=Development;Science;
EOF

# Bundle dependencies (Qt5, libs) with linuxdeploy (no --output: only updates AppDir; appimagetool creates the .AppImage)
echo ">>> Bundling dependencies with linuxdeploy..."
LINUXDEPLOY="$BUILD_DIR/linuxdeploy-x86_64.AppImage"
PLUGIN_QT="$BUILD_DIR/linuxdeploy-plugin-qt-x86_64.AppImage"
for url in "$LINUXDEPLOY_URL" "$LINUXDEPLOY_PLUGIN_QT_URL"; do
  f="$BUILD_DIR/$(basename "$url")"
  if [[ ! -f "$f" ]]; then
    echo ">>> Downloading $(basename "$f")..."
    wget -q -O "$f" "$url"
    chmod +x "$f"
  fi
done
ELF_BINS=()
for f in "$ROOT/bin"/*; do
  [[ -f "$f" ]] && [[ -x "$f" ]] && file -b "$f" | grep -q "ELF" && ELF_BINS+=("$f")
done
if [[ ${#ELF_BINS[@]} -eq 0 ]]; then
  echo ">>> Warning: no ELF binaries found in $ROOT/bin; only Qt will be bundled."
fi
LINUXDEPLOY_CMD=("$LINUXDEPLOY" --appdir="$APPDIR" --plugin qt)
for exe in "${ELF_BINS[@]}"; do LINUXDEPLOY_CMD+=(--executable "$exe"); done
if [[ ${#ELF_BINS[@]} -gt 0 ]]; then
  "${LINUXDEPLOY_CMD[@]}"
else
  "$LINUXDEPLOY" --appdir="$APPDIR" --plugin qt
fi

# Download appimagetool if not present
APPIMAGETOOL="$BUILD_DIR/appimagetool-x86_64.AppImage"
if [[ ! -f "$APPIMAGETOOL" ]]; then
  echo ">>> Downloading appimagetool..."
  wget -q -O "$APPIMAGETOOL" "$APPIMAGETOOL_URL"
  chmod +x "$APPIMAGETOOL"
fi

# Build the AppImage
APPIMAGE_OUT="$OUTPUT_DIR/$APPIMAGE_NAME"
echo ">>> Building AppImage: $APPIMAGE_OUT"
ARCH=x86_64 "$APPIMAGETOOL" --no-appstream "$APPDIR" "$APPIMAGE_OUT"

echo ""
echo ">>> Done. AppImage created: $APPIMAGE_OUT"
echo ">>> Run: $APPIMAGE_OUT"
echo ">>> For console simulations: $APPIMAGE_OUT opp_run [options]"
echo ">>> Includes Qt5 and bundled dependencies; on the system only Python3 is recommended (present on Ubuntu)."
echo ""

if [[ -n "${CLEAN_BUILD}" ]]; then
  echo ">>> Removing build directory: $BUILD_DIR"
  rm -rf "$BUILD_DIR"
fi
