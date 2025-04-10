#!/bin/bash

# Actualizar el sistema
sudo apt-get update

# Instalar paquetes requeridos
sudo apt-get -y install build-essential clang lld gdb bison flex perl \
python3 python3-pip qtbase5-dev qtchooser qt5-qmake qtbase5-dev-tools \
libqt5opengl5-dev libxml2-dev zlib1g-dev doxygen graphviz \
xdg-utils
sudo apt-get -y install libwebkit2gtk-4.0-37
sudo apt-get -y install python3-numpy python3-scipy python3-matplotlib python3-pandas python3-seaborn


# Instalar bibliotecas para el desarrollo de MPI
sudo apt-get -y install mpi-default-dev

# Instalar la biblioteca libstdc++-12-dev
sudo apt-get -y install libstdc++-12-dev

# Descargar OMNeT++ 6.0.1
wget -c https://github.com/omnetpp/omnetpp/releases/download/omnetpp-6.0.1/omnetpp-6.0.1-linux-x86_64.tgz

# Descomprimir el archivo descargado
tar xzf omnetpp-6.0.1-linux-x86_64.tgz

python3 -m venv omnetpp-6.0.1/venv

# Activar el entorno
source omnetpp-6.0.1/venv/bin/activate

# Instalar las dependencias de Python
pip install --upgrade pip
pip install numpy pandas matplotlib scipy seaborn posix_ipc

# Navegar al directorio de OMNeT++
cd omnetpp-6.0.1

# Configurar el entorno de OMNeT++
source setenv

# Deshabilitar Open Scene Graph (OSG)
sed -i 's/WITH_OSG=yes/WITH_OSG=no/' configure.user

# Configurar OMNeT++
./configure

# Compilar OMNeT++
make -j$(nproc)

# Instalar los accesos directos de OMNeT++
make install-shortcuts

# Permitir el acceso a PTRACE para depuración
sudo sed -i 's/kernel.yama.ptrace_scope = 1/kernel.yama.ptrace_scope = 0/' /etc/sysctl.d/10-ptrace.conf

