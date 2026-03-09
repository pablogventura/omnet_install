#!/bin/bash
#
# Test OMNeT++ with interfaz gráfica, de dos maneras:
#
#   --x11       Usa la pantalla de tu máquina (X11). La ventana de OMNeT++ se abre en tu escritorio.
#               Requiere: xhost +local:docker (una vez) y DISPLAY en el host.
#
#   --browser   Arranca un escritorio en un contenedor y lo sirve por noVNC. Abrís http://localhost:6901
#               en el navegador y ves el escritorio; ahí podés abrir una terminal y ejecutar OMNeT++
#               para comprobar que la IDE carga.
#
#   --browser-check  Igual que --browser pero además hace un chequeo automático: lanza la IDE en el
#                    contenedor, espera y comprueba si apareció una ventana con "OMNeT" (wmctrl).
#                    Útil para CI o para no tener que mirar el navegador.
#
# Uso:
#   ./test_gui_docker.sh --x11 [ruta/al/AppImage]
#   ./test_gui_docker.sh --browser [ruta/al/AppImage]
#   ./test_gui_docker.sh --browser-check [ruta/al/AppImage]
#   ./test_gui_docker.sh --browser .deb [ruta/al/paquete.deb]
#
# Por defecto se usa el AppImage en el directorio actual (OMNeT++-6.0.1-x86_64.AppImage).
# Requiere: Docker. Para --browser/--browser-check se usa la imagen accetto/ubuntu-vnc-xfce-g3.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODE=""
TYPE="appimage"
FILE_ARG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --x11|--browser|--browser-check)
      MODE="$1"
      shift
      ;;
    .deb)
      TYPE="deb"
      shift
      ;;
    *)
      FILE_ARG="$1"
      shift
      ;;
  esac
done

if [[ -z "$MODE" ]]; then
  echo "Uso: $0 --x11 | --browser | --browser-check [.deb] [ruta/al/archivo]"
  echo ""
  echo "  --x11           Ventana en tu pantalla (X11 forwarding)"
  echo "  --browser       Escritorio en http://localhost:6901 (noVNC); abrís el navegador y ejecutás OMNeT++"
  echo "  --browser-check Como --browser pero el script comprueba solo si la ventana de OMNeT++ apareció"
  echo ""
  echo "Ejemplos:"
  echo "  $0 --browser ./OMNeT++-6.0.1-x86_64.AppImage"
  echo "  $0 --browser-check"
  echo "  $0 --browser .deb ./omnetpp_6.0.1-1_amd64.deb"
  exit 1
fi

if [[ "$TYPE" == "deb" ]]; then
  OMNET_VERSION="${OMNET_VERSION:-6.0.1}"
  DEB="${FILE_ARG:-$SCRIPT_DIR/omnetpp_${OMNET_VERSION}-1_amd64.deb}"
  DEB_ABS="$(cd "$(dirname "$DEB")" && pwd)/$(basename "$DEB")"
  DEB_DIR="$(dirname "$DEB_ABS")"
  DEB_NAME="$(basename "$DEB_ABS")"
  if [[ ! -f "$DEB_ABS" ]]; then
    echo "Error: .deb no encontrado: $DEB_ABS"
    exit 1
  fi
  APPIMAGE_ABS=""
else
  OMNET_VERSION="${OMNET_VERSION:-6.0.1}"
  APPIMAGE="${FILE_ARG:-$SCRIPT_DIR/OMNeT++-${OMNET_VERSION}-x86_64.AppImage}"
  APPIMAGE_ABS="$(cd "$(dirname "$APPIMAGE")" && pwd)/$(basename "$APPIMAGE")"
  if [[ ! -f "$APPIMAGE_ABS" ]]; then
    echo "Error: AppImage no encontrado: $APPIMAGE_ABS"
    exit 1
  fi
  APPIMAGE_NAME="$(basename "$APPIMAGE_ABS")"
  APPIMAGE_DIR="$(dirname "$APPIMAGE_ABS")"
fi

# --- Modo X11: ventana en el host
run_x11() {
  if [[ -z "$DISPLAY" ]]; then
    echo "Error: DISPLAY no está definido. Ejecutá este script en una sesión con escritorio (X11 o Wayland+Xwayland)."
    exit 1
  fi
  echo ">>> Modo X11: la ventana de OMNeT++ se abrirá en tu pantalla."
  echo ">>> Si falla, probá en el host: xhost +local:docker"
  echo ""
  if [[ -n "$APPIMAGE_ABS" ]]; then
    docker run --rm -it \
      -e DISPLAY="$DISPLAY" \
      -e APPIMAGE_EXTRACT_AND_RUN=1 \
      -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
      -v "$APPIMAGE_DIR:/mnt:ro" \
      ubuntu:22.04 \
      bash -c '
        apt-get update -qq && apt-get install -y -qq libfuse2 libgtk-3-0 libxtst6 libxi6 libxrender1 libxfixes3 > /dev/null
        chmod +x "/mnt/'"$(basename "$APPIMAGE_ABS")"'"
        echo "Abriendo OMNeT++..."
        exec "/mnt/'"$(basename "$APPIMAGE_ABS")"'"
      '
  else
    echo "Modo X11 con .deb: instalar el .deb en el contenedor y ejecutar omnetpp (requiere más dependencias)."
    echo "Recomendación: usá --browser con el .deb para probar la IDE."
    exit 1
  fi
}

# --- Modo browser (noVNC): escritorio en http://localhost:6901
# En accetto/ubuntu-vnc-xfce-g3 el usuario headless tiene $HOME=/home/headless; el Desktop puede estar ahí
NOVNC_IMAGE="${NOVNC_IMAGE:-accetto/ubuntu-vnc-xfce-g3}"
NOVNC_PORT="${NOVNC_PORT:-6901}"
CONTAINER_NAME="omnet-gui-test-$$"
DESKTOP_DIR="/home/headless/Desktop"

run_browser() {
  echo ">>> Arrancando escritorio con noVNC (imagen: $NOVNC_IMAGE)"
  echo ">>> Abrí en el navegador: http://localhost:$NOVNC_PORT"
  echo ">>> Contraseña por defecto: headless (usuario headless)."
  echo ""
  if [[ -n "$APPIMAGE_ABS" ]]; then
    docker run -d --name "$CONTAINER_NAME" \
      -p "${NOVNC_PORT}:6901" \
      -e VNC_PW=headless \
      -v "$APPIMAGE_DIR:/opt/mnt:ro" \
      "$NOVNC_IMAGE" \
      > /dev/null
    docker exec "$CONTAINER_NAME" bash -c "
      chmod +x /opt/mnt/$(basename "$APPIMAGE_ABS") 2>/dev/null || true
      mkdir -p $DESKTOP_DIR
      echo '#!/bin/bash' > $DESKTOP_DIR/run-omnetpp.sh
      echo 'export APPIMAGE_EXTRACT_AND_RUN=1' >> $DESKTOP_DIR/run-omnetpp.sh
      echo 'exec /opt/mnt/$(basename "$APPIMAGE_ABS")' >> $DESKTOP_DIR/run-omnetpp.sh
      chmod +x $DESKTOP_DIR/run-omnetpp.sh
      chown headless:headless $DESKTOP_DIR/run-omnetpp.sh 2>/dev/null || true
    "
    echo ">>> En el escritorio: doble clic en 'run-omnetpp.sh' o en una terminal: APPIMAGE_EXTRACT_AND_RUN=1 /opt/mnt/$(basename "$APPIMAGE_ABS")"
  else
    docker run -d --name "$CONTAINER_NAME" \
      -p "${NOVNC_PORT}:6901" \
      -e VNC_PW=headless \
      -v "$DEB_DIR:/mnt/deb:ro" \
      "$NOVNC_IMAGE" \
      > /dev/null
    docker exec "$CONTAINER_NAME" bash -c "
      apt-get update -qq && apt-get install -y -qq dpkg apt-utils > /dev/null
      dpkg -i /mnt/deb/$DEB_NAME || true
      apt-get install -f -y -qq
      mkdir -p $DESKTOP_DIR
      echo '#!/bin/bash' > $DESKTOP_DIR/run-omnetpp.sh
      echo 'exec omnetpp' >> $DESKTOP_DIR/run-omnetpp.sh
      chmod +x $DESKTOP_DIR/run-omnetpp.sh
      chown headless:headless $DESKTOP_DIR/run-omnetpp.sh 2>/dev/null || true
    " 2>/dev/null
    echo ">>> En el escritorio: doble clic en 'run-omnetpp.sh' o en una terminal: omnetpp"
  fi
  echo ""
  echo ">>> Contenedor: $CONTAINER_NAME. Para parar: docker stop $CONTAINER_NAME"
  echo ""
  echo "Abrí http://localhost:$NOVNC_PORT y comprobá que OMNeT++ arranca."
}

# --- Modo browser-check: mismo que browser pero hace chequeo automático con wmctrl
run_browser_check() {
  run_browser
  echo ">>> Esperando 5 s a que el escritorio esté listo..."
  sleep 5
  echo ">>> Instalando wmctrl y lanzando OMNeT++ en el contenedor..."
  if [[ -n "$APPIMAGE_ABS" ]]; then
    APPIMAGE_BASENAME="$(basename "$APPIMAGE_ABS")"
    docker exec "$CONTAINER_NAME" bash -c "
      apt-get update -qq && apt-get install -y -qq wmctrl > /dev/null
      sudo -u headless env DISPLAY=:1 APPIMAGE_EXTRACT_AND_RUN=1 /opt/mnt/$APPIMAGE_BASENAME &
    " 2>/dev/null || true
  else
    docker exec "$CONTAINER_NAME" bash -c "
      apt-get update -qq && apt-get install -y -qq wmctrl > /dev/null
      sudo -u headless env DISPLAY=:1 omnetpp &
    " 2>/dev/null || true
  fi
  echo ">>> Esperando 30 s a que la ventana de OMNeT++ aparezca..."
  sleep 30
  FOUND=$(docker exec "$CONTAINER_NAME" bash -c "DISPLAY=:1 wmctrl -l 2>/dev/null | grep -i omnet || true") || true
  docker stop "$CONTAINER_NAME" > /dev/null 2>&1 || true
  docker rm "$CONTAINER_NAME" > /dev/null 2>&1 || true
  if [[ -n "$FOUND" ]]; then
    echo ">>> OK: Se detectó ventana de OMNeT++ en el escritorio."
    echo "$FOUND"
    exit 0
  else
    echo ">>> FAIL: No se detectó ninguna ventana con 'OMNeT' en el título (wmctrl -l)."
    echo ">>> Podés usar --browser (sin -check) y abrir http://localhost:$NOVNC_PORT para comprobar a mano."
    exit 1
  fi
}

case "$MODE" in
  --x11)    run_x11 ;;
  --browser) run_browser ;;
  --browser-check) run_browser_check ;;
  *) echo "Modo no implementado: $MODE"; exit 1 ;;
esac
