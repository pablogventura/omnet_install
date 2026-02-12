#!/bin/bash
#
# Script to build an installable .deb package of OMNeT++ 6.0.1
# Usage: ./build_omnet_deb.sh [output_directory]
# Example: ./build_omnet_deb.sh ./dist
#
# Requirements: debian/rpm tools (dpkg-deb), wget, tar, and OMNeT++ build
# dependencies (the script can install them with -d).
#

set -e

OMNET_VERSION="${OMNET_VERSION:-6.0.1}"
OMNET_TARBALL="omnetpp-${OMNET_VERSION}-linux-x86_64.tgz"
OMNET_URL="https://github.com/omnetpp/omnetpp/releases/download/omnetpp-${OMNET_VERSION}/${OMNET_TARBALL}"
INSTALL_PREFIX="/opt/omnetpp-${OMNET_VERSION}"
OUTPUT_DIR="${1:-.}"
BUILD_DIR="${BUILD_DIR:-$(mktemp -d)}"
PKG_NAME="omnetpp"
PKG_VERSION="${OMNET_VERSION}-1"
PKG_ARCH="amd64"

# Install build dependencies only (optional)
install_build_deps() {
    echo ">>> Installing build dependencies..."
    sudo apt-get update
    sudo apt-get -y install build-essential clang lld gdb bison flex perl \
        python3 python3-pip python3-venv qtbase5-dev qtchooser qt5-qmake qtbase5-dev-tools \
        libqt5opengl5-dev libxml2-dev zlib1g-dev doxygen graphviz xdg-utils \
        python3-numpy python3-scipy python3-matplotlib python3-pandas python3-seaborn \
        mpi-default-dev libstdc++-12-dev
    # WebKit: different package name on Ubuntu 24.04 (4.1) vs 22.04 (4.0-37)
    sudo apt-get -y install libwebkit2gtk-4.1-0 2>/dev/null \
        || sudo apt-get -y install libwebkit2gtk-4.0-37 2>/dev/null \
        || echo ">>> Warning: libwebkit2gtk not installed (optional for the IDE)"
}

usage() {
    echo "Usage: $0 [OPTIONS] [output_directory]"
    echo ""
    echo "Builds an OMNeT++ ${OMNET_VERSION} .deb package."
    echo ""
    echo "  -d, --install-deps   Install build dependencies before building"
    echo "  -h, --help            Show this help"
    echo ""
    echo "  output_directory     Folder where the .deb will be saved (default: .)"
    echo ""
    echo "Environment variables:"
    echo "  OMNET_VERSION        OMNeT++ version (default: ${OMNET_VERSION})"
    echo "  BUILD_DIR            Temporary build directory (default: temporary)"
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

# Check minimum build tools
check_build_tools() {
    local missing=()
    command -v bison >/dev/null 2>&1 || missing+=(bison)
    command -v flex  >/dev/null 2>&1 || missing+=(flex)
    command -v g++   >/dev/null 2>&1 || missing+=(g++)
    command -v make  >/dev/null 2>&1 || missing+=(make)
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo ">>> Error: missing build tools: ${missing[*]}"
        echo ">>> Install with: $0 -d"
        echo ">>> Or manually: sudo apt-get install bison flex build-essential"
        exit 1
    fi
}
check_build_tools

mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
mkdir -p "$BUILD_DIR"
BUILD_DIR="$(cd "$BUILD_DIR" && pwd)"

echo ">>> Build directory: $BUILD_DIR"
echo ">>> .deb output: $OUTPUT_DIR"
echo ">>> Version: $OMNET_VERSION"
echo ""

# Descargar OMNeT++
if [[ ! -f "$BUILD_DIR/$OMNET_TARBALL" ]]; then
    echo ">>> Downloading $OMNET_URL ..."
    wget -c -O "$BUILD_DIR/$OMNET_TARBALL" "$OMNET_URL"
else
    echo ">>> Using existing tarball: $BUILD_DIR/$OMNET_TARBALL"
fi

echo ">>> Extracting..."
tar xzf "$BUILD_DIR/$OMNET_TARBALL" -C "$BUILD_DIR"

SRC_DIR="$BUILD_DIR/omnetpp-${OMNET_VERSION}"
STAGING="$BUILD_DIR/deb_staging"
ROOT="$STAGING${INSTALL_PREFIX}"

mkdir -p "$STAGING"

# Venv and Python dependencies must exist before configure (configure checks posix_ipc, etc.)
echo ">>> Creating venv and Python dependencies for the build..."
python3 -m venv "$SRC_DIR/venv"
"$SRC_DIR/venv/bin/pip" install --upgrade pip -q
"$SRC_DIR/venv/bin/pip" install numpy pandas matplotlib scipy seaborn posix_ipc -q

# Build OMNeT++ (with venv active so configure finds Python modules)
echo ">>> Configuring and building OMNeT++..."
cd "$SRC_DIR"
source setenv 2>/dev/null || true
# Activate venv so python3 has posix_ipc and the rest
export PATH="$SRC_DIR/venv/bin:$PATH"
export VIRTUAL_ENV="$SRC_DIR/venv"
sed -i 's/WITH_OSG=yes/WITH_OSG=no/' configure.user
./configure --prefix="$INSTALL_PREFIX"
NPROC=$(nproc)
echo ">>> Building with $NPROC threads..."
make -j"$NPROC"

# Install to staging: OMNeT++ does not support make install, we copy the built tree
echo ">>> Copying build tree into package..."
mkdir -p "$ROOT"
cp -a "$SRC_DIR"/* "$ROOT/"
# Replace build path with install path (avoids IDE suggesting workspace in /tmp/...)
# Generic pattern: any /tmp/tmp.XXX/omnetpp-VERSION (in case temp dir name changes)
echo ">>> Fixing paths in configuration files..."
OMNET_VER_SED="${OMNET_VERSION//./\\.}"
SED_TMP_PATTERN="/tmp/tmp\.[^/]*/omnetpp-${OMNET_VER_SED}"
replace_build_path() {
  sed -i "s|${SED_TMP_PATTERN}|${INSTALL_PREFIX}|g" "$1" 2>/dev/null || true
  sed -i "s|${SRC_DIR}|${INSTALL_PREFIX}|g" "$1" 2>/dev/null || true
}
# 1) Files by extension
while IFS= read -r -d '' f; do
  replace_build_path "$f"
done < <(find "$ROOT" -type f \( -name "*.ini" -o -name "*.properties" -o -name "*.xml" -o -name "*.cfg" -o -name "*.conf" -o -name "*.user" -o -name "*.launch" -o -name "*.prefs" -o -name "*.product" -o -name "config.ini" \) ! -path "*/venv/*" -print0 2>/dev/null)
# 2) Entire ide/ tree (Eclipse stores workspace here by default)
[[ -d "$ROOT/ide" ]] && find "$ROOT/ide" -type f ! -path "*/venv/*" 2>/dev/null | while read -r f; do
  case "$(file -b --mime-type "$f" 2>/dev/null)" in text/*) replace_build_path "$f" ;; esac
done
# 3) Any other text file that still contains the path (pattern /tmp/tmp.XXX/...)
while IFS= read -r -d '' f; do
  [[ "$f" == *"/venv/"* ]] && continue
  case "$(file -b --mime-type "$f" 2>/dev/null)" in text/*) replace_build_path "$f" ;; esac
done < <(grep -rZl --fixed-strings "/tmp/tmp." "$ROOT" 2>/dev/null)
# Ensure execute permissions for setenv and binaries
[[ -f "$ROOT/setenv" ]] && chmod +x "$ROOT/setenv"
[[ -d "$ROOT/bin" ]] && chmod +x "$ROOT/bin"/* 2>/dev/null || true

# Create and configure venv in the packaged tree
echo ">>> Configuring Python environment (venv) in the package..."
python3 -m venv "$ROOT/venv"
"$ROOT/venv/bin/pip" install --upgrade pip -q
"$ROOT/venv/bin/pip" install numpy pandas matplotlib scipy seaborn posix_ipc -q

# Wrapper in /usr/bin/omnetpp so "omnetpp" can be run from console without source setenv
mkdir -p "$STAGING/usr/bin"
cat > "$STAGING/usr/bin/omnetpp" << WRAPPER
#!/bin/bash
export OMNETPP_ROOT="${INSTALL_PREFIX}"
export PATH="\${OMNETPP_ROOT}/bin:\$PATH"
exec "\${OMNETPP_ROOT}/bin/omnetpp" "\$@"
WRAPPER
chmod 755 "$STAGING/usr/bin/omnetpp"

# Wrapper for opp_run so any user can run simulations without source setenv
cat > "$STAGING/usr/bin/opp_run" << WRAPPER
#!/bin/bash
export OMNETPP_ROOT="${INSTALL_PREFIX}"
export PATH="\${OMNETPP_ROOT}/bin:\$PATH"
exec "\${OMNETPP_ROOT}/bin/opp_run" "\$@"
WRAPPER
chmod 755 "$STAGING/usr/bin/opp_run"

# Application menu icon: .desktop in /usr/share/applications
# Priority: official logo (images/logo/), then ide/, then generic
mkdir -p "$STAGING/usr/share/applications"
OMNET_ICON=""
[[ -f "$ROOT/images/logo/logo128.png" ]] && OMNET_ICON="${INSTALL_PREFIX}/images/logo/logo128.png"
[[ -z "$OMNET_ICON" ]] && [[ -f "$ROOT/images/logo/logo128s.png" ]] && OMNET_ICON="${INSTALL_PREFIX}/images/logo/logo128s.png"
[[ -z "$OMNET_ICON" ]] && [[ -f "$ROOT/ide/icon.png" ]] && OMNET_ICON="${INSTALL_PREFIX}/ide/icon.png"
[[ -z "$OMNET_ICON" ]] && [[ -f "$ROOT/ide/omnetpp.png" ]] && OMNET_ICON="${INSTALL_PREFIX}/ide/omnetpp.png"
[[ -z "$OMNET_ICON" ]] && OMNET_ICON="utilities-terminal"
{
  echo '[Desktop Entry]'
  echo 'Version=1.0'
  echo 'Type=Application'
  echo "Name=OMNeT++ ${OMNET_VERSION} IDE"
  echo 'Comment=OMNeT++ Discrete Event Simulation IDE'
  echo 'Exec=/usr/bin/omnetpp'
  echo "Icon=$OMNET_ICON"
  echo 'Terminal=false'
  echo 'Categories=Development;Science;'
} > "$STAGING/usr/share/applications/omnetpp.desktop"
chmod 644 "$STAGING/usr/share/applications/omnetpp.desktop"

# .deb package metadata
DEBIAN_DIR="$STAGING/DEBIAN"
mkdir -p "$DEBIAN_DIR"

INSTALLED_SIZE=$(du -sk "$ROOT" 2>/dev/null | cut -f1)
[[ -z "$INSTALLED_SIZE" ]] && INSTALLED_SIZE=0

cat > "$DEBIAN_DIR/control" << EOF
Package: ${PKG_NAME}
Version: ${PKG_VERSION}
Section: science
Priority: optional
Architecture: ${PKG_ARCH}
Installed-Size: ${INSTALLED_SIZE}
Depends: libc6 (>= 2.34), libstdc++6 (>= 10), libgcc-s1 (>= 4.2), libqt5core5a, libqt5gui5, libqt5widgets5, libqt5opengl5, libxml2 (>= 2.9.0), zlib1g (>= 1:1.2.0), python3 (>= 3.8), python3-numpy, libopenmpi3
Maintainer: OMNeT++ Package Builder <omnet@local>
Description: OMNeT++ Discrete Event Simulator
 OMNeT++ ${OMNET_VERSION} - Network simulation framework.
 Installed in ${INSTALL_PREFIX}.
 Commands in PATH: omnetpp (IDE), opp_run (simulator). No need for source setenv.
EOF

# postinst: shortcuts, permissions and symlinks (INSTALL_PREFIX is expanded when generating the script)
cat > "$DEBIAN_DIR/postinst" << POSTINST
#!/bin/sh
set -e
# Execute permissions in case the package did not bring them
[ -f "${INSTALL_PREFIX}/setenv" ] && chmod +x "${INSTALL_PREFIX}/setenv"
[ -d "${INSTALL_PREFIX}/bin" ] && chmod +x "${INSTALL_PREFIX}/bin"/* 2>/dev/null || true
# IDE writes error.log and others in ide/; allow write for all users
[ -d "${INSTALL_PREFIX}/ide" ] && chmod -R a+w "${INSTALL_PREFIX}/ide" 2>/dev/null || true
# samples/ is the default workspace: must be writable so the IDE does not say "read only"
[ -d "${INSTALL_PREFIX}/samples" ] && chmod -R a+w "${INSTALL_PREFIX}/samples" 2>/dev/null || true
# Update application menu so the OMNeT++ icon appears
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database /usr/share/applications 2>/dev/null || true
POSTINST

chmod 755 "$DEBIAN_DIR/postinst"

# postrm: on uninstall/purge, remove menu icon and wrappers (in case dpkg did not remove them)
cat > "$DEBIAN_DIR/postrm" << POSTRM
#!/bin/sh
set -e
case "\$1" in
  remove|purge)
    rm -f /usr/share/applications/omnetpp.desktop
    rm -f /usr/bin/omnetpp /usr/bin/opp_run
    command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database /usr/share/applications 2>/dev/null || true
    ;;
esac
POSTRM

chmod 755 "$DEBIAN_DIR/postrm"

# Build the .deb
DEB_FILE="${OUTPUT_DIR}/${PKG_NAME}_${PKG_VERSION}_${PKG_ARCH}.deb"
echo ">>> Building .deb package: $DEB_FILE"
dpkg-deb --root-owner-group -b "$STAGING" "$DEB_FILE"

echo ""
echo ">>> Done. Package created: $DEB_FILE"
echo ">>> Install with: sudo dpkg -i $DEB_FILE"
echo ">>> If dependencies are missing: sudo apt-get install -f"
echo ">>> OMNeT++ will be in ${INSTALL_PREFIX}. To use: source ${INSTALL_PREFIX}/setenv"
echo ""

# Optional cleanup of temporary directory
if [[ -n "${CLEAN_BUILD}" ]]; then
    echo ">>> Removing build directory: $BUILD_DIR"
    rm -rf "$BUILD_DIR"
fi
