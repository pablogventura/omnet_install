#!/bin/bash

# Update the system
sudo apt-get update

# Install required packages
sudo apt-get -y install build-essential clang lld gdb bison flex perl \
python3 python3-pip qtbase5-dev qtchooser qt5-qmake qtbase5-dev-tools \
libqt5opengl5-dev libxml2-dev zlib1g-dev doxygen graphviz \
xdg-utils
sudo apt-get -y install libwebkit2gtk-4.0-37
sudo apt-get -y install python3-numpy python3-scipy python3-matplotlib python3-pandas python3-seaborn


# Install MPI development libraries
sudo apt-get -y install mpi-default-dev

# Install libstdc++-12-dev library
sudo apt-get -y install libstdc++-12-dev

# Download OMNeT++ 6.0.1
wget -c https://github.com/omnetpp/omnetpp/releases/download/omnetpp-6.0.1/omnetpp-6.0.1-linux-x86_64.tgz

# Extract the downloaded file
tar xzf omnetpp-6.0.1-linux-x86_64.tgz

python3 -m venv omnetpp-6.0.1/venv

# Activate the environment
source omnetpp-6.0.1/venv/bin/activate

# Install Python dependencies
pip install --upgrade pip
pip install numpy pandas matplotlib scipy seaborn posix_ipc

# Change to OMNeT++ directory
cd omnetpp-6.0.1

# Configure OMNeT++ environment
source setenv

# Disable Open Scene Graph (OSG)
sed -i 's/WITH_OSG=yes/WITH_OSG=no/' configure.user

# Configure OMNeT++
./configure

# Build OMNeT++
make -j$(nproc)

# Install OMNeT++ shortcuts
make install-shortcuts

# Allow PTRACE access for debugging
sudo sed -i 's/kernel.yama.ptrace_scope = 1/kernel.yama.ptrace_scope = 0/' /etc/sysctl.d/10-ptrace.conf

