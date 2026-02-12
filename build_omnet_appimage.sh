#!/bin/bash
#
# Script para generar un AppImage portable de OMNeT++ 6.0.1
# Uso: ./build_omnet_appimage.sh [directorio_salida]
#
# Requisitos: wget, tar, dependencias de compilación de OMNeT++ (opcional -d).
# Genera un AppDir y usa appimagetool (se descarga si no está) para crear el .AppImage.
#
# Incluye dependencias (Qt5, libs del sistema) vía linuxdeploy + plugin Qt para que
# no haga falta instalar paquetes en Ubuntu. Python3 y venv siguen en el árbol de OMNeT++.
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

# Instalar solo dependencias de construcción (opcional)
install_build_deps() {
    echo ">>> Instalando dependencias de construcción..."
    sudo apt-get update
    sudo apt-get -y install build-essential clang lld gdb bison flex perl \
        python3 python3-pip python3-venv qtbase5-dev qtchooser qt5-qmake qtbase5-dev-tools \
        libqt5opengl5-dev libxml2-dev zlib1g-dev doxygen graphviz xdg-utils \
        python3-numpy python3-scipy python3-matplotlib python3-pandas python3-seaborn \
        mpi-default-dev libstdc++-12-dev
    sudo apt-get -y install libwebkit2gtk-4.1-0 2>/dev/null \
        || sudo apt-get -y install libwebkit2gtk-4.0-37 2>/dev/null \
        || echo ">>> Aviso: no se instaló libwebkit2gtk (opcional para la IDE)"
}

usage() {
    echo "Uso: $0 [OPCIONES] [directorio_salida]"
    echo ""
    echo "Genera un AppImage de OMNeT++ ${OMNET_VERSION}."
    echo ""
    echo "  -d, --install-deps   Instalar dependencias de construcción antes de compilar"
    echo "  -h, --help           Mostrar esta ayuda"
    echo ""
    echo "  directorio_salida   Carpeta donde se guardará el .AppImage (por defecto: .)"
    echo ""
    echo "Variables de entorno:"
    echo "  OMNET_VERSION        Versión de OMNeT++ (por defecto: ${OMNET_VERSION})"
    echo "  BUILD_DIR            Directorio de compilación (por defecto: temporal). Si lo fijas"
    echo "                       (ej. BUILD_DIR=./build) y vuelves a ejecutar, se reutiliza la compilación."
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

check_build_tools() {
    local missing=()
    command -v bison >/dev/null 2>&1 || missing+=(bison)
    command -v flex  >/dev/null 2>&1 || missing+=(flex)
    command -v g++   >/dev/null 2>&1 || missing+=(g++)
    command -v make  >/dev/null 2>&1 || missing+=(make)
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo ">>> Error: faltan herramientas de compilación: ${missing[*]}"
        echo ">>> Instálalas con: $0 -d"
        exit 1
    fi
}
check_build_tools

mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
mkdir -p "$BUILD_DIR"
BUILD_DIR="$(cd "$BUILD_DIR" && pwd)"

echo ">>> Directorio de compilación: $BUILD_DIR"
echo ">>> Salida AppImage: $OUTPUT_DIR"
echo ">>> Versión: $OMNET_VERSION"
echo ">>> (Para reutilizar esta compilación: BUILD_DIR=$BUILD_DIR $0)"
echo ""

SRC_DIR="$BUILD_DIR/omnetpp-${OMNET_VERSION}"
APPDIR="$BUILD_DIR/OMNeT++.AppDir"
ROOT="$APPDIR${INSTALL_PREFIX}"
REUSE_BUILD=false
[[ -x "$SRC_DIR/bin/opp_run" ]] && REUSE_BUILD=true

if [[ "$REUSE_BUILD" == true ]]; then
  echo ">>> Reutilizando compilación existente en $SRC_DIR"
else
  # Descargar OMNeT++
  if [[ ! -f "$BUILD_DIR/$OMNET_TARBALL" ]]; then
    echo ">>> Descargando $OMNET_URL ..."
    wget -c -O "$BUILD_DIR/$OMNET_TARBALL" "$OMNET_URL"
  else
    echo ">>> Usando tarball existente: $BUILD_DIR/$OMNET_TARBALL"
  fi

  echo ">>> Descomprimiendo..."
  tar xzf "$BUILD_DIR/$OMNET_TARBALL" -C "$BUILD_DIR"

  # Venv y dependencias Python para la compilación
  echo ">>> Creando venv y dependencias Python para la compilación..."
  python3 -m venv "$SRC_DIR/venv"
  "$SRC_DIR/venv/bin/pip" install --upgrade pip -q
  "$SRC_DIR/venv/bin/pip" install numpy pandas matplotlib scipy seaborn posix_ipc -q

  # Compilar OMNeT++
  echo ">>> Configurando y compilando OMNeT++..."
  cd "$SRC_DIR"
  source setenv 2>/dev/null || true
  export PATH="$SRC_DIR/venv/bin:$PATH"
  export VIRTUAL_ENV="$SRC_DIR/venv"
  sed -i 's/WITH_OSG=yes/WITH_OSG=no/' configure.user
  ./configure --prefix="$INSTALL_PREFIX"
  NPROC=$(nproc)
  echo ">>> Compilando con $NPROC hilos..."
  make -j"$NPROC"
fi

mkdir -p "$APPDIR"

# Copiar árbol al AppDir
echo ">>> Copiando árbol de compilación al AppDir..."
mkdir -p "$ROOT"
cp -a "$SRC_DIR"/* "$ROOT/"

# Sustituir rutas de compilación por ruta de instalación
echo ">>> Corrigiendo rutas en archivos de configuración..."
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

# Venv en el AppDir
echo ">>> Configurando entorno Python (venv) en el AppDir..."
python3 -m venv "$ROOT/venv"
"$ROOT/venv/bin/pip" install --upgrade pip -q
"$ROOT/venv/bin/pip" install numpy pandas matplotlib scipy seaborn posix_ipc -q

# AppRun, icono y .desktop antes de linuxdeploy (evita WARNING y permite integración)
echo ">>> Creando AppRun, icono y .desktop..."
cat > "$APPDIR/AppRun" << 'APPRUN'
#!/bin/bash
set -e
APPDIR="$(dirname "$(readlink -f "$0")")"
# Librerías empaquetadas (Qt5, etc.) en el AppImage
export LD_LIBRARY_PATH="${APPDIR}/usr/lib:${APPDIR}/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH}"
READONLY_ROOT="${APPDIR}/opt/omnetpp-6.0.1"
WRITABLE_BASE="${XDG_DATA_HOME:-$HOME/.local/share}"
WRITABLE_OMNET="${WRITABLE_BASE}/omnetpp-6.0.1"

# opp_run no escribe en ide/; puede ejecutarse desde el montaje read-only
if [[ "${1:-}" == "opp_run" ]] || [[ "${1:-}" == "run" ]]; then
  export OMNETPP_ROOT="$READONLY_ROOT"
  export PATH="${OMNETPP_ROOT}/bin:${PATH}"
  exec "${OMNETPP_ROOT}/bin/opp_run" "${@:2}"
fi

# IDE: necesita escribir en ide/ (error.log, workspace, etc.) -> usar copia escribible
if [[ ! -d "$WRITABLE_OMNET/bin" ]]; then
  echo "Primera ejecución: copiando OMNeT++ a ${WRITABLE_OMNET} (puede tardar un momento)..."
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

# Empaquetar dependencias (Qt5, libs) con linuxdeploy (sin --output: solo actualiza AppDir; el .AppImage lo crea appimagetool)
echo ">>> Empaquetando dependencias con linuxdeploy..."
LINUXDEPLOY="$BUILD_DIR/linuxdeploy-x86_64.AppImage"
PLUGIN_QT="$BUILD_DIR/linuxdeploy-plugin-qt-x86_64.AppImage"
for url in "$LINUXDEPLOY_URL" "$LINUXDEPLOY_PLUGIN_QT_URL"; do
  f="$BUILD_DIR/$(basename "$url")"
  if [[ ! -f "$f" ]]; then
    echo ">>> Descargando $(basename "$f")..."
    wget -q -O "$f" "$url"
    chmod +x "$f"
  fi
done
ELF_BINS=()
for f in "$ROOT/bin"/*; do
  [[ -f "$f" ]] && [[ -x "$f" ]] && file -b "$f" | grep -q "ELF" && ELF_BINS+=("$f")
done
if [[ ${#ELF_BINS[@]} -eq 0 ]]; then
  echo ">>> Aviso: no se encontraron binarios ELF en $ROOT/bin; se empaquetará solo Qt."
fi
LINUXDEPLOY_CMD=("$LINUXDEPLOY" --appdir="$APPDIR" --plugin qt)
for exe in "${ELF_BINS[@]}"; do LINUXDEPLOY_CMD+=(--executable "$exe"); done
if [[ ${#ELF_BINS[@]} -gt 0 ]]; then
  "${LINUXDEPLOY_CMD[@]}"
else
  "$LINUXDEPLOY" --appdir="$APPDIR" --plugin qt
fi

# Descargar appimagetool si no está
APPIMAGETOOL="$BUILD_DIR/appimagetool-x86_64.AppImage"
if [[ ! -f "$APPIMAGETOOL" ]]; then
  echo ">>> Descargando appimagetool..."
  wget -q -O "$APPIMAGETOOL" "$APPIMAGETOOL_URL"
  chmod +x "$APPIMAGETOOL"
fi

# Generar el AppImage
APPIMAGE_OUT="$OUTPUT_DIR/$APPIMAGE_NAME"
echo ">>> Generando AppImage: $APPIMAGE_OUT"
ARCH=x86_64 "$APPIMAGETOOL" --no-appstream "$APPDIR" "$APPIMAGE_OUT"

echo ""
echo ">>> Listo. AppImage creado: $APPIMAGE_OUT"
echo ">>> Ejecutar: $APPIMAGE_OUT"
echo ">>> Para simulaciones desde consola: $APPIMAGE_OUT opp_run [opciones]"
echo ">>> Incluye Qt5 y dependencias empaquetadas; en el sistema solo se recomienda Python3 (presente en Ubuntu)."
echo ""

if [[ -n "${CLEAN_BUILD}" ]]; then
  echo ">>> Eliminando directorio de compilación: $BUILD_DIR"
  rm -rf "$BUILD_DIR"
fi
