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
# Sustituir ruta de compilación por ruta de instalación (evita que la IDE proponga workspace en /tmp/...)
# Patrón genérico: cualquier /tmp/tmp.XXX/omnetpp-VERSION (por si el nombre del dir temporal cambia)
echo ">>> Corrigiendo rutas en archivos de configuración..."
OMNET_VER_SED="${OMNET_VERSION//./\\.}"
SED_TMP_PATTERN="/tmp/tmp\.[^/]*/omnetpp-${OMNET_VER_SED}"
replace_build_path() {
  sed -i "s|${SED_TMP_PATTERN}|${INSTALL_PREFIX}|g" "$1" 2>/dev/null || true
  sed -i "s|${SRC_DIR}|${INSTALL_PREFIX}|g" "$1" 2>/dev/null || true
}
# 1) Archivos por extensión
while IFS= read -r -d '' f; do
  replace_build_path "$f"
done < <(find "$ROOT" -type f \( -name "*.ini" -o -name "*.properties" -o -name "*.xml" -o -name "*.cfg" -o -name "*.conf" -o -name "*.user" -o -name "*.launch" -o -name "*.prefs" -o -name "*.product" -o -name "config.ini" \) ! -path "*/venv/*" -print0 2>/dev/null)
# 2) Todo el árbol ide/ (Eclipse guarda workspace por defecto aquí)
[[ -d "$ROOT/ide" ]] && find "$ROOT/ide" -type f ! -path "*/venv/*" 2>/dev/null | while read -r f; do
  case "$(file -b --mime-type "$f" 2>/dev/null)" in text/*) replace_build_path "$f" ;; esac
done
# 3) Cualquier otro archivo de texto que aún contenga la ruta (patrón /tmp/tmp.XXX/...)
while IFS= read -r -d '' f; do
  [[ "$f" == *"/venv/"* ]] && continue
  case "$(file -b --mime-type "$f" 2>/dev/null)" in text/*) replace_build_path "$f" ;; esac
done < <(grep -rZl --fixed-strings "/tmp/tmp." "$ROOT" 2>/dev/null)
# Asegurar permisos de ejecución para setenv y binarios
[[ -f "$ROOT/setenv" ]] && chmod +x "$ROOT/setenv"
[[ -d "$ROOT/bin" ]] && chmod +x "$ROOT/bin"/* 2>/dev/null || true

# Crear y configurar venv en el árbol empaquetado
echo ">>> Configurando entorno Python (venv) en el paquete..."
python3 -m venv "$ROOT/venv"
"$ROOT/venv/bin/pip" install --upgrade pip -q
"$ROOT/venv/bin/pip" install numpy pandas matplotlib scipy seaborn posix_ipc -q

# Wrapper en /usr/bin/omnetpp para poder ejecutar "omnetpp" en consola sin source setenv
mkdir -p "$STAGING/usr/bin"
cat > "$STAGING/usr/bin/omnetpp" << WRAPPER
#!/bin/bash
export OMNETPP_ROOT="${INSTALL_PREFIX}"
export PATH="\${OMNETPP_ROOT}/bin:\$PATH"
exec "\${OMNETPP_ROOT}/bin/omnetpp" "\$@"
WRAPPER
chmod 755 "$STAGING/usr/bin/omnetpp"

# Wrapper opp_run para que cualquier usuario pueda ejecutar simulaciones sin source setenv
cat > "$STAGING/usr/bin/opp_run" << WRAPPER
#!/bin/bash
export OMNETPP_ROOT="${INSTALL_PREFIX}"
export PATH="\${OMNETPP_ROOT}/bin:\$PATH"
exec "\${OMNETPP_ROOT}/bin/opp_run" "\$@"
WRAPPER
chmod 755 "$STAGING/usr/bin/opp_run"

# Icono en el menú de aplicaciones: .desktop en /usr/share/applications
mkdir -p "$STAGING/usr/share/applications"
OMNET_ICON=""
[[ -f "$ROOT/ide/icon.png" ]] && OMNET_ICON="${INSTALL_PREFIX}/ide/icon.png"
[[ -z "$OMNET_ICON" ]] && [[ -f "$ROOT/ide/omnetpp.png" ]] && OMNET_ICON="${INSTALL_PREFIX}/ide/omnetpp.png"
[[ -z "$OMNET_ICON" ]] && OMNET_ICON="utilities-terminal"
{
  echo '[Desktop Entry]'
  echo 'Version=1.0'
  echo 'Type=Application'
  echo 'Name=OMNeT++'
  echo 'Comment=OMNeT++ Discrete Event Simulation IDE'
  echo 'Exec=/usr/bin/omnetpp'
  echo "Icon=$OMNET_ICON"
  echo 'Terminal=false'
  echo 'Categories=Development;Science;'
} > "$STAGING/usr/share/applications/omnetpp.desktop"
chmod 644 "$STAGING/usr/share/applications/omnetpp.desktop"

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
 Comandos en PATH: omnetpp (IDE), opp_run (simulador). Sin necesidad de source setenv.
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
# samples/ es el workspace por defecto: debe ser escribible para que la IDE no diga "read only"
[ -d "${INSTALL_PREFIX}/samples" ] && chmod -R a+w "${INSTALL_PREFIX}/samples" 2>/dev/null || true
# Actualizar menú de aplicaciones para que aparezca el icono de OMNeT++
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database /usr/share/applications 2>/dev/null || true
POSTINST

chmod 755 "$DEBIAN_DIR/postinst"

# postrm: al desinstalar/purgar, quitar icono del menú y wrappers (por si dpkg no los eliminó)
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
