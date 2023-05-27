cd ~ && sudo apt-get update && sudo apt-get -y install build-essential clang lld gdb bison flex perl \
python3 python3-pip qtbase5-dev qtchooser qt5-qmake qtbase5-dev-tools \
libqt5opengl5-dev libxml2-dev zlib1g-dev doxygen graphviz \
libwebkit2gtk-4.0-37 xdg-utils && python3 -m pip install --user --upgrade numpy pandas matplotlib scipy \
seaborn posix_ipc && sudo apt-get -y install mpi-default-dev && sudo apt-get -y install libstdc++-12-dev && cd ~ && wget -c https://github.com/omnetpp/omnetpp/releases/download/omnetpp-6.0.1/omnetpp-6.0.1-linux-x86_64.tgz && tar xzf omnetpp-6.0.1-linux-x86_64.tgz && cd omnetpp-6.0.1 && source setenv && sed -i 's/WITH_OSG=yes/WITH_OSG=no/' configure.user && ./configure && make -j$(nproc) && make install-shortcuts && sudo sed -i 's/kernel.yama.ptrace_scope = 1/kernel.yama.ptrace_scope = 0/' /etc/sysctl.d/10-ptrace.conf

