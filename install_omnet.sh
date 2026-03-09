#!/bin/bash
# Direct installation of OMNeT++. Version configurable via OMNET_VERSION (default 6.0.1).

OMNET_VERSION="${OMNET_VERSION:-6.0.1}"
OMNET_TARBALL="omnetpp-${OMNET_VERSION}-linux-x86_64.tgz"
OMNET_URL="https://github.com/omnetpp/omnetpp/releases/download/omnetpp-${OMNET_VERSION}/${OMNET_TARBALL}"
OMNET_DIR="omnetpp-${OMNET_VERSION}"

# Update the system
sudo apt-get update

# Install required packages
sudo apt-get -y install build-essential clang lld gdb bison flex perl \
python3 python3-pip qtbase5-dev qtchooser qt5-qmake qtbase5-dev-tools \
libqt5opengl5-dev libxml2-dev zlib1g-dev doxygen graphviz \
xdg-utils
sudo apt-get -y install libwebkit2gtk-4.1-0 2>/dev/null \
  || sudo apt-get -y install libwebkit2gtk-4.0-37 2>/dev/null \
  || echo "Warning: libwebkit2gtk not installed (optional for the IDE)"
sudo apt-get -y install python3-numpy python3-scipy python3-matplotlib python3-pandas python3-seaborn


# Install MPI development libraries
sudo apt-get -y install mpi-default-dev

# Install libstdc++-12-dev library
sudo apt-get -y install libstdc++-12-dev

# Download OMNeT++
wget -c "$OMNET_URL" -O "$OMNET_TARBALL"

# Extract the downloaded file
tar xzf "$OMNET_TARBALL"

python3 -m venv "$OMNET_DIR/venv"

# Activate the environment
source "$OMNET_DIR/venv/bin/activate"

# Install Python dependencies
pip install --upgrade pip
pip install numpy pandas matplotlib scipy seaborn posix_ipc

# Change to OMNeT++ directory
cd "$OMNET_DIR"

# Configure OMNeT++ environment
source setenv

# Disable Open Scene Graph (OSG)
# configure.user may not exist (tarball ships configure.user.dist)
if [ -f configure.user.dist ] && [ ! -f configure.user ]; then
  cp configure.user.dist configure.user
fi
if [ -f configure.user ]; then
  sed -i 's/WITH_OSG=yes/WITH_OSG=no/' configure.user
fi

# Configure OMNeT++
./configure

# Build OMNeT++
make -j$(nproc)

# Install OMNeT++ shortcuts
make install-shortcuts

# Allow PTRACE access for debugging (only if the file exists on this distro)
if [ -f /etc/sysctl.d/10-ptrace.conf ]; then
  sudo sed -i 's/kernel.yama.ptrace_scope = 1/kernel.yama.ptrace_scope = 0/' /etc/sysctl.d/10-ptrace.conf
fi

