#!/bin/bash
#
# Script para generar un paquete .deb instalable de OMNeT++ 6.0.1
# Uso: ./build_omnet_deb.sh [directorio_salida]
# Ejemplo: ./build_omnet_deb.sh ./dist
#
# Requisitos: debian/rpm tools (dpkg-deb), wget, tar, y las dependencias
# de compilación de OMNeT++ (el script puede instalarlas con -d).
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

# Instalar solo dependencias de construcción (opcional)
install_build_deps() {
    echo ">>> Instalando dependencias de construcción..."
    sudo apt-get update
    sudo apt-get -y install build-essential clang lld gdb bison flex perl \
        python3 python3-pip python3-venv qtbase5-dev qtchooser qt5-qmake qtbase5-dev-tools \
        libqt5opengl5-dev libxml2-dev zlib1g-dev doxygen graphviz xdg-utils \
        python3-numpy python3-scipy python3-matplotlib python3-pandas python3-seaborn \
        mpi-default-dev libstdc++-12-dev
    # WebKit: nombre distinto en Ubuntu 24.04 (4.1) vs 22.04 (4.0-37)
    sudo apt-get -y install libwebkit2gtk-4.1-0 2>/dev/null \
        || sudo apt-get -y install libwebkit2gtk-4.0-37 2>/dev/null \
        || echo ">>> Aviso: no se instaló libwebkit2gtk (opcional para la IDE)"
}

usage() {
    echo "Uso: $0 [OPCIONES] [directorio_salida]"
    echo ""
    echo "Genera un paquete .deb de OMNeT++ ${OMNET_VERSION}."
    echo ""
    echo "  -d, --install-deps   Instalar dependencias de construcción antes de compilar"
    echo "  -h, --help           Mostrar esta ayuda"
    echo ""
    echo "  directorio_salida    Carpeta donde se guardará el .deb (por defecto: .)"
    echo ""
    echo "Variables de entorno:"
    echo "  OMNET_VERSION        Versión de OMNeT++ (por defecto: ${OMNET_VERSION})"
    echo "  BUILD_DIR            Directorio de compilación temporal (por defecto: temporal)"
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
            echo "Opción desconocida: $1"
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

# Comprobar herramientas mínimas de compilación
check_build_tools() {
    local missing=()
    command -v bison >/dev/null 2>&1 || missing+=(bison)
    command -v flex  >/dev/null 2>&1 || missing+=(flex)
    command -v g++   >/dev/null 2>&1 || missing+=(g++)
    command -v make  >/dev/null 2>&1 || missing+=(make)
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo ">>> Error: faltan herramientas de compilación: ${missing[*]}"
        echo ">>> Instálalas con: $0 -d"
        echo ">>> O manualmente: sudo apt-get install bison flex build-essential"
        exit 1
    fi
}
check_build_tools

mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
mkdir -p "$BUILD_DIR"
BUILD_DIR="$(cd "$BUILD_DIR" && pwd)"

echo ">>> Directorio de compilación: $BUILD_DIR"
echo ">>> Salida .deb: $OUTPUT_DIR"
echo ">>> Versión: $OMNET_VERSION"
echo ""

# Descargar OMNeT++
if [[ ! -f "$BUILD_DIR/$OMNET_TARBALL" ]]; then
    echo ">>> Descargando $OMNET_URL ..."
    wget -c -O "$BUILD_DIR/$OMNET_TARBALL" "$OMNET_URL"
else
    echo ">>> Usando tarball existente: $BUILD_DIR/$OMNET_TARBALL"
fi

echo ">>> Descomprimiendo..."
tar xzf "$BUILD_DIR/$OMNET_TARBALL" -C "$BUILD_DIR"

SRC_DIR="$BUILD_DIR/omnetpp-${OMNET_VERSION}"
STAGING="$BUILD_DIR/deb_staging"
ROOT="$STAGING${INSTALL_PREFIX}"

mkdir -p "$STAGING"

# Venv y dependencias Python deben existir antes de configure (configure comprueba posix_ipc, etc.)
echo ">>> Creando venv y dependencias Python para la compilación..."
python3 -m venv "$SRC_DIR/venv"
"$SRC_DIR/venv/bin/pip" install --upgrade pip -q
"$SRC_DIR/venv/bin/pip" install numpy pandas matplotlib scipy seaborn posix_ipc -q

# Compilar OMNeT++ (con venv activado para que configure encuentre los módulos Python)
echo ">>> Configurando y compilando OMNeT++..."
cd "$SRC_DIR"
source setenv 2>/dev/null || true
# Activar venv para que python3 tenga posix_ipc y el resto
export PATH="$SRC_DIR/venv/bin:$PATH"
export VIRTUAL_ENV="$SRC_DIR/venv"
sed -i 's/WITH_OSG=yes/WITH_OSG=no/' configure.user
./configure --prefix="$INSTALL_PREFIX"
NPROC=$(nproc)
echo ">>> Compilando con $NPROC hilos..."
make -j"$NPROC"

# Instalar en staging: OMNeT++ no instala con make install, copiamos el árbol compilado
echo ">>> Copiando árbol de compilación al paquete..."
mkdir -p "$ROOT"
cp -a "$SRC_DIR"/* "$ROOT/"
# Asegurar permisos de ejecución para setenv y binarios
[[ -f "$ROOT/setenv" ]] && chmod +x "$ROOT/setenv"
[[ -d "$ROOT/bin" ]] && chmod +x "$ROOT/bin"/* 2>/dev/null || true

# Crear y configurar venv en el árbol empaquetado
echo ">>> Configurando entorno Python (venv) en el paquete..."
python3 -m venv "$ROOT/venv"
"$ROOT/venv/bin/pip" install --upgrade pip -q
"$ROOT/venv/bin/pip" install numpy pandas matplotlib scipy seaborn posix_ipc -q

# Crear enlaces en /usr/bin y shortcuts (se pueden instalar en postinst)
# Por ahora dejamos el árbol en /opt y documentamos que el usuario puede usar setenv

# Metadatos del paquete .deb
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
 Installado en ${INSTALL_PREFIX}.
 Para usar: source ${INSTALL_PREFIX}/setenv
 O ejecutar: ${INSTALL_PREFIX}/bin/opp_run (y demás binarios en bin/)
EOF

# postinst: atajos, permisos y symlinks (INSTALL_PREFIX se expande al generar el script)
cat > "$DEBIAN_DIR/postinst" << POSTINST
#!/bin/sh
set -e
# Permisos de ejecución por si el paquete no los trajo
[ -f "${INSTALL_PREFIX}/setenv" ] && chmod +x "${INSTALL_PREFIX}/setenv"
[ -d "${INSTALL_PREFIX}/bin" ] && chmod +x "${INSTALL_PREFIX}/bin"/* 2>/dev/null || true
# La IDE escribe error.log y otros en ide/; permitir escritura a todos los usuarios
[ -d "${INSTALL_PREFIX}/ide" ] && chmod -R a+w "${INSTALL_PREFIX}/ide" 2>/dev/null || true
# Crear symlink para opp_run si existe el directorio
if [ -d "${INSTALL_PREFIX}" ] && [ -x "${INSTALL_PREFIX}/bin/opp_run" ] && [ ! -e /usr/bin/opp_run ]; then
    ln -sf "${INSTALL_PREFIX}/bin/opp_run" /usr/bin/opp_run 2>/dev/null || true
fi
# Actualizar base de datos de escritorio si hay .desktop
if [ -d "${INSTALL_PREFIX}/share/applications" ]; then
    command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database /usr/share/applications 2>/dev/null || true
fi
POSTINST

chmod 755 "$DEBIAN_DIR/postinst"

# Construir el .deb
DEB_FILE="${OUTPUT_DIR}/${PKG_NAME}_${PKG_VERSION}_${PKG_ARCH}.deb"
echo ">>> Generando paquete .deb: $DEB_FILE"
dpkg-deb --root-owner-group -b "$STAGING" "$DEB_FILE"

echo ""
echo ">>> Listo. Paquete creado: $DEB_FILE"
echo ">>> Instalar con: sudo dpkg -i $DEB_FILE"
echo ">>> Si faltan dependencias: sudo apt-get install -f"
echo ">>> OMNeT++ quedará en ${INSTALL_PREFIX}. Para usarlo: source ${INSTALL_PREFIX}/setenv"
echo ""

# Limpieza opcional del directorio temporal
if [[ -n "${CLEAN_BUILD}" ]]; then
    echo ">>> Eliminando directorio de compilación: $BUILD_DIR"
    rm -rf "$BUILD_DIR"
fi
