#!/bin/bash
#
# Construye el AppImage de OMNeT++ dentro de un contenedor Ubuntu 22.04.
# Así el binario queda enlazado contra la glibc de 22.04 y el AppImage
# funciona en Ubuntu 22.04 (y en 24.04).
#
# Uso: ./build_omnet_appimage_docker.sh [directorio_salida]
#   Por defecto el AppImage se deja en el directorio actual.
#
# Requiere: Docker. La primera vez tarda ~20–40 min (imagen, deps, compilación y linuxdeploy).
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="${1:-$SCRIPT_DIR}"
OUTPUT_ABS="$(cd "$(dirname "$OUTPUT_DIR")" && pwd)/$(basename "$OUTPUT_DIR")"
OMNET_VERSION="${OMNET_VERSION:-6.0.1}"
APPIMAGE_NAME="OMNeT++-${OMNET_VERSION}-x86_64.AppImage"

echo ">>> Construyendo AppImage de OMNeT++ en Docker (Ubuntu 22.04)"
echo ">>> Salida: $OUTPUT_ABS"
echo ""

docker run --rm \
  -v "$SCRIPT_DIR:/mnt:ro" \
  -v "$OUTPUT_ABS:/output" \
  -e DEBIAN_FRONTEND=noninteractive \
  -e OMNET_VERSION="$OMNET_VERSION" \
  -e APPIMAGE_EXTRACT_AND_RUN=1 \
  ubuntu:22.04 \
  bash -c '
    set -e
    echo ">>> Instalando dependencias de build..."
    apt-get update -qq
    apt-get install -y -qq \
      build-essential clang lld gdb bison flex perl \
      python3 python3-pip python3-venv \
      qtbase5-dev qtchooser qt5-qmake qtbase5-dev-tools \
      libqt5opengl5-dev libxml2-dev zlib1g-dev doxygen graphviz xdg-utils \
      python3-numpy python3-scipy python3-matplotlib python3-pandas python3-seaborn \
      mpi-default-dev libstdc++-12-dev \
      wget libfuse2 unzip > /dev/null
    apt-get install -y -qq libwebkit2gtk-4.0-37 2>/dev/null || true

    echo ">>> Ejecutando build_omnet_appimage.sh (salida en /output)..."
    /mnt/build_omnet_appimage.sh /output
    echo ""
    echo ">>> AppImage generado en /output (montado en el host)."
  '

echo ""
echo ">>> Listo. AppImage: $OUTPUT_ABS/$APPIMAGE_NAME"
echo ">>> Probar en 22.04 y 24.04: SKIP_INSTALL=1 ./test_all_docker.sh"
echo ""
