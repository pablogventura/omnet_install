# OMNeT++ Install — Scripts de instalación y empaquetado

Scripts para instalar y empaquetar **OMNeT++ 6.0.1** en sistemas Linux (Debian/Ubuntu): instalación directa, paquete `.deb` o **AppImage** portable.

[OMNeT++](https://omnetpp.org/) es un framework de simulación discreta por eventos, orientado a redes y sistemas.

---

## Resumen de opciones

| Opción | Script | Resultado |
|--------|--------|-----------|
| **Instalación directa** | `install_omnet.sh` | OMNeT++ compilado e instalado en el directorio actual |
| **Paquete .deb** | `build_omnet_deb.sh` | Paquete `.deb` instalable en `/opt/omnetpp-6.0.1` |
| **AppImage** | `build_omnet_appimage.sh` | Ejecutable portable con Qt y dependencias incluidas |

---

## Opción 1: Instalación directa

Instala OMNeT++ y dependencias en el sistema, compilando desde el tarball oficial.

### Requisitos

- Linux (Debian/Ubuntu)
- Conexión a Internet
- Permisos de superusuario (para instalar paquetes)

### Uso

```bash
# Descargar y ejecutar (requiere confiar en la fuente)
wget -qO- https://raw.githubusercontent.com/pablogventura/omnet_install/main/install_omnet.sh | bash
```

Durante la ejecución se pedirá la contraseña de superusuario. Al terminar:

- OMNeT++ queda en `./omnetpp-6.0.1/`
- Se crean accesos directos en el menú de aplicaciones
- Para usar en terminal: `source omnetpp-6.0.1/setenv` y luego `omnetpp` o `opp_run`

---

## Opción 2: Paquete .deb

Genera un paquete `.deb` que instala OMNeT++ en `/opt/omnetpp-6.0.1` y añade los comandos `omnetpp` y `opp_run` en el PATH (sin necesidad de `source setenv`).

### Requisitos para construir

- `dpkg-deb`, `wget`, `tar`
- Herramientas de compilación (bison, flex, g++, make, etc.); el script puede instalarlas con `-d`

### Uso

```bash
chmod +x build_omnet_deb.sh

# Generar el .deb en el directorio actual
./build_omnet_deb.sh

# Salida en una carpeta concreta
./build_omnet_deb.sh ./dist

# Instalar dependencias de compilación y luego generar el .deb
./build_omnet_deb.sh -d ./dist
```

### Instalar el paquete generado

```bash
sudo dpkg -i omnetpp_6.0.1-1_amd64.deb
# Si faltan dependencias:
sudo apt-get install -f
```

Tras la instalación:

- OMNeT++ en `/opt/omnetpp-6.0.1`
- Comandos en PATH: `omnetpp` (IDE), `opp_run` (simulador)

### Variables de entorno (build)

- **`OMNET_VERSION`**: versión de OMNeT++ (por defecto: `6.0.1`)
- **`BUILD_DIR`**: directorio temporal de compilación (por defecto: se crea uno con `mktemp -d`)

---

## Opción 3: AppImage

Genera un **AppImage** portable de OMNeT++ con Qt5 y dependencias empaquetadas (linuxdeploy + plugin Qt), útil para distribuir o usar sin instalar paquetes en el sistema.

### Requisitos para construir

- `wget`, `tar`, herramientas de compilación (opcionalmente `-d` para instalarlas)
- En el sistema destino solo se recomienda tener Python3 (habitual en Ubuntu)

### Uso

```bash
chmod +x build_omnet_appimage.sh

# Generar el AppImage en el directorio actual
./build_omnet_appimage.sh

# Salida en una carpeta concreta
./build_omnet_appimage.sh ./dist

# Instalar dependencias de compilación y luego generar
./build_omnet_appimage.sh -d ./dist
```

### Ejecutar el AppImage

```bash
# Abrir la IDE
./OMNeT++-6.0.1-x86_64.AppImage

# Ejecutar simulaciones desde consola
./OMNeT++-6.0.1-x86_64.AppImage opp_run [opciones]
./OMNeT++-6.0.1-x86_64.AppImage run [opciones]
```

En el primer arranque de la IDE, el AppImage copia OMNeT++ a `~/.local/share/omnetpp-6.0.1` para permitir escritura (workspace, logs, etc.).

### Variables de entorno (build)

- **`OMNET_VERSION`**: versión de OMNeT++ (por defecto: `6.0.1`)
- **`BUILD_DIR`**: directorio temporal de compilación
- **`CLEAN_BUILD`**: si está definida, se elimina el directorio de compilación al finalizar

---

## Dependencias de compilación (opciones 2 y 3)

Los scripts `build_omnet_deb.sh` y `build_omnet_appimage.sh` pueden instalar las dependencias de compilación con la opción **`-d`** o **`--install-deps`**:

- build-essential, clang, lld, gdb, bison, flex, perl  
- Qt5 (qtbase5-dev, qt5-qmake, libqt5opengl5-dev, etc.)  
- libxml2-dev, zlib1g-dev, doxygen, graphviz, xdg-utils  
- Python3 y venv: numpy, scipy, matplotlib, pandas, seaborn, posix_ipc  
- mpi-default-dev, libstdc++-12-dev  
- libwebkit2gtk (opcional, para la IDE)

---

## Estructura del repositorio

```
.
├── install_omnet.sh        # Instalación directa
├── build_omnet_deb.sh      # Generar paquete .deb
├── build_omnet_appimage.sh # Generar AppImage
├── .gitignore
└── README.md
```

---

## Notas

- **Versión por defecto**: 6.0.1 (configurable con `OMNET_VERSION` en los scripts de build).
- **Open Scene Graph (OSG)**: se deshabilita en la compilación (`WITH_OSG=no`) para evitar dependencias adicionales.
- **Python**: los scripts crean un `venv` dentro del árbol de OMNeT++ con numpy, pandas, matplotlib, scipy, seaborn y posix_ipc, requeridos por el framework.
