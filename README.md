# OMNeT++ Install — Installation and packaging scripts

Scripts to install and package **OMNeT++ 6.0.1** on Linux (Debian/Ubuntu): direct installation, `.deb` package, or portable **AppImage**.

[OMNeT++](https://omnetpp.org/) is a discrete event simulation framework for networks and systems.

---

## Summary of options

| Option | Script | Result |
|--------|--------|--------|
| **Direct installation** | `install_omnet.sh` | OMNeT++ built and installed in the current directory |
| **.deb package** | `build_omnet_deb.sh` | Installable `.deb` package in `/opt/omnetpp-6.0.1` |
| **AppImage** | `build_omnet_appimage.sh` | Portable executable with Qt and dependencies bundled |

---

## Option 1: Direct installation

Installs OMNeT++ and dependencies on the system, building from the official tarball.

### Requirements

- Linux (Debian/Ubuntu)
- Internet connection
- Superuser privileges (to install packages)

### Usage

```bash
# Download and run (requires trusting the source)
wget -qO- https://raw.githubusercontent.com/pablogventura/omnet_install/main/install_omnet.sh | bash
```

You will be prompted for the superuser password during execution. When finished:

- OMNeT++ is in `./omnetpp-6.0.1/`
- Application menu shortcuts are created
- To use from terminal: `source omnetpp-6.0.1/setenv` then `omnetpp` or `opp_run`
- If the IDE does not appear in PATH, open a new terminal or launch **OMNeT++** from the applications menu

---

## Option 2: .deb package

Builds a `.deb` package that installs OMNeT++ in `/opt/omnetpp-6.0.1` and adds the `omnetpp` and `opp_run` commands to PATH (no need for `source setenv`).

### Build requirements

- `dpkg-deb`, `wget`, `tar`
- Build tools (bison, flex, g++, make, etc.); the script can install them with `-d`

### Usage

```bash
chmod +x build_omnet_deb.sh

# Generate the .deb in the current directory
./build_omnet_deb.sh

# Output to a specific folder
./build_omnet_deb.sh ./dist

# Install build dependencies and then generate the .deb
./build_omnet_deb.sh -d ./dist
```

**Construir el .deb en Docker (recomendado para probar en 22.04 y 24.04):**  
Si construís el .deb en un host con glibc más nuevo (p. ej. Ubuntu 24.04), el paquete puede no ejecutarse en Ubuntu 22.04. Para un .deb que funcione en **ambas** versiones, construilo dentro de un contenedor Ubuntu 22.04:

```bash
./build_omnet_deb_docker.sh
# O con directorio de salida:
./build_omnet_deb_docker.sh ./dist
```

Requiere Docker. La primera ejecución tarda ~15–30 min (descarga de imagen, dependencias y compilación).

### Installing the generated package

```bash
sudo dpkg -i omnetpp_6.0.1-1_amd64.deb
# If dependencies are missing:
sudo apt-get install -f
```

After installation:

- OMNeT++ in `/opt/omnetpp-6.0.1`
- Commands in PATH: `omnetpp` (IDE), `opp_run` (simulator)

### Environment variables (build)

- **`OMNET_VERSION`**: OMNeT++ version (default: `6.0.1`)
- **`BUILD_DIR`**: Temporary build directory (default: created with `mktemp -d`)

---

## Option 3: AppImage

Builds a portable **AppImage** of OMNeT++ with Qt5 and dependencies bundled (linuxdeploy + Qt plugin), for distribution or use without installing system packages.

### Build requirements

- `wget`, `tar`, build tools (optionally `-d` to install them)
- On the target system, Python3 is recommended (common on Ubuntu)

### Usage

```bash
chmod +x build_omnet_appimage.sh

# Generate the AppImage in the current directory
./build_omnet_appimage.sh

# Output to a specific folder
./build_omnet_appimage.sh ./dist

# Install build dependencies and then generate
./build_omnet_appimage.sh -d ./dist
```

**Construir el AppImage en Docker (compatible con Ubuntu 22.04 y 24.04):**  
Para que el AppImage funcione en **Ubuntu 22.04** (y por tanto también en 24.04), conviene construirlo dentro de un contenedor Ubuntu 22.04; si se construye en un host con glibc más nuevo, puede fallar en 22.04.

```bash
./build_omnet_appimage_docker.sh
# O con directorio de salida:
./build_omnet_appimage_docker.sh ./dist
```

Requiere Docker. La primera ejecución tarda ~20–40 min.

### Running the AppImage

```bash
# Open the IDE
./OMNeT++-6.0.1-x86_64.AppImage

# Run simulations from the console
./OMNeT++-6.0.1-x86_64.AppImage opp_run [options]
./OMNeT++-6.0.1-x86_64.AppImage run [options]
```

On first IDE launch, the AppImage copies OMNeT++ to `~/.local/share/omnetpp-6.0.1` for writable workspace, logs, etc.

### AppImage troubleshooting

- **First run**: The IDE copy to `~/.local/share/omnetpp-6.0.1` can take a moment; subsequent launches are faster.
- **"Could not load SWT library"** (e.g. on Ubuntu 22.04): The build script copies SWT native libs into the AppImage’s `usr/lib`. After building, the script prints how many `libswt-pi4*.so` files are in `usr/lib`; if that count is 0, the IDE may fail. Run the AppImage with **`DEBUG_OMNET_APPIMAGE=1`** to print paths and config (e.g. `DEBUG_OMNET_APPIMAGE=1 ./OMNeT++-6.0.1-x86_64.AppImage`).
- **Other native errors** (e.g. missing symbols, GLIBC version): SWT depends on GTK/glibc on the host; document the distro and error for support. For maximum portability, the target distro should be similar to the build distro.

### Environment variables (build)

- **`OMNET_VERSION`**: OMNeT++ version (default: `6.0.1`)
- **`BUILD_DIR`**: Temporary build directory
- **`CLEAN_BUILD`**: If set, the build directory is removed when finished

### Environment variables (runtime)

- **`DEBUG_OMNET_APPIMAGE=1`**: Print APPDIR, WRITABLE_OMNET, eclipse.ini presence and SWT lib count before launching the IDE (for troubleshooting).

### Testing with Docker (Ubuntu 22.04 and 24.04)

All three delivery methods can be tested inside **Ubuntu 22.04 or 24.04** containers. Requires Docker. By default `test_all_docker.sh` runs each test on both versions.

| Test | Script | What it does |
|------|--------|---------------|
| **Instalador** | `test_install_docker.sh [22.04\|24.04]` | Runs `install_omnet.sh` in the container (download + build, 15–30 min), then checks `opp_run --version` and `bin/omnetpp`. |
| **.deb** | `test_deb_docker.sh [path/to.deb] [22.04\|24.04]` | Installs the .deb in the container, runs `apt-get install -f`, then checks `opp_run` and `omnetpp` in PATH. Build the .deb first with `./build_omnet_deb.sh`. |
| **AppImage** | `test_appimage_docker.sh [path/to.AppImage] [22.04\|24.04]` | Runs the AppImage in the container, checks SWT libs and `opp_run --version`. |

Run all tests on both Ubuntu versions (skips install test if `SKIP_INSTALL=1`; skips .deb/AppImage if the files are not found):

```bash
./test_all_docker.sh
# Skip the long install test:
SKIP_INSTALL=1 ./test_all_docker.sh
# Only Ubuntu 24.04:
UBUNTU_VERSIONS="24.04" ./test_all_docker.sh
# Look for .deb and AppImage in a specific directory:
./test_all_docker.sh ./dist
```

### Tests con interfaz gráfica (ver que la IDE carga)

Para comprobar que la IDE de OMNeT++ abre bien (no solo `opp_run`), podés usar **`test_gui_docker.sh`** de dos maneras:

| Modo | Descripción |
|------|-------------|
| **`--x11`** | La ventana de OMNeT++ se abre en **tu pantalla**. Requiere X11 (o Wayland con Xwayland) y una vez en el host: `xhost +local:docker`. |
| **`--browser`** | Arranca un **escritorio en un contenedor** y lo sirve por **noVNC**. Abrís **http://localhost:6901** en el navegador y ves el escritorio; ahí abrís una terminal o el lanzador y ejecutás OMNeT++ para ver si la IDE carga. |
| **`--browser-check`** | Igual que `--browser` pero el script hace un **chequeo automático**: lanza la IDE en el contenedor, espera y comprueba con `wmctrl` si apareció una ventana con "OMNeT" en el título. Sirve para CI o para no tener que mirar el navegador. |

Ejemplos:

```bash
# Escritorio en el navegador (abrís http://localhost:6901 y ejecutás OMNeT++ a mano)
./test_gui_docker.sh --browser ./OMNeT++-6.0.1-x86_64.AppImage

# Chequeo automático: el script dice OK o FAIL según si detecta la ventana
./test_gui_docker.sh --browser-check

# Con el .deb (instala el .deb en el contenedor y dejá el escritorio listo para ejecutar omnetpp)
./test_gui_docker.sh --browser .deb ./omnetpp_6.0.1-1_amd64.deb

# Ventana en tu pantalla (X11)
./test_gui_docker.sh --x11 ./OMNeT++-6.0.1-x86_64.AppImage
```

Para `--browser` y `--browser-check` se usa la imagen **accetto/ubuntu-vnc-xfce-g3** (Ubuntu + Xfce + noVNC). Usuario/contraseña por defecto: **headless** / **headless**.

---

## Build dependencies (options 2 and 3)

The scripts `build_omnet_deb.sh` and `build_omnet_appimage.sh` can install build dependencies with the **`-d`** or **`--install-deps`** option:

- build-essential, clang, lld, gdb, bison, flex, perl  
- Qt5 (qtbase5-dev, qt5-qmake, libqt5opengl5-dev, etc.)  
- libxml2-dev, zlib1g-dev, doxygen, graphviz, xdg-utils  
- Python3 and venv: numpy, scipy, matplotlib, pandas, seaborn, posix_ipc  
- mpi-default-dev, libstdc++-12-dev  
- libwebkit2gtk (optional, for the IDE)

---

## Repository structure

```
.
├── install_omnet.sh         # Direct installation
├── build_omnet_deb.sh       # Build .deb package
├── build_omnet_deb_docker.sh    # Build .deb inside Ubuntu 22.04 Docker (for 22.04 + 24.04)
├── build_omnet_appimage.sh      # Build AppImage
├── build_omnet_appimage_docker.sh # Build AppImage inside Ubuntu 22.04 Docker (for 22.04 + 24.04)
├── test_install_docker.sh   # Test install script in Ubuntu 22.04/24.04 (Docker)
├── test_deb_docker.sh       # Test .deb install in Ubuntu 22.04/24.04 (Docker)
├── test_appimage_docker.sh  # Test AppImage in Ubuntu 22.04/24.04 (Docker)
├── test_all_docker.sh       # Run all Docker tests
├── test_gui_docker.sh       # Test con GUI: --x11 (ventana en tu pantalla) o --browser/--browser-check (noVNC)
├── .gitignore
└── README.md
```

---

## Licencia y redistribución de binarios

**OMNeT++** está bajo la [Academic Public License (APL)](https://omnetpp.org/intro/license): uso gratuito para fines **no comerciales** (académicos, enseñanza, investigación, uso personal). El uso comercial requiere licencia de [OMNEST](https://www.omnest.com/).

Podés **compartir** los `.deb` y el AppImage generados por este repo (por ejemplo en GitHub Releases) sin violar la licencia, siempre que:

1. **Solo sea uso no comercial** (quien los descargue también debe usarlos bajo APL).
2. **Acompañes los binarios** con esta información:
   - Que OMNeT++ está bajo la **Academic Public License**.
   - **Código fuente** de la versión usada: en el proyecto oficial, por ejemplo para 6.0.1:  
     [https://github.com/omnetpp/omnetpp/releases/tag/omnetpp-6.0.1](https://github.com/omnetpp/omnetpp/releases/tag/omnetpp-6.0.1)  
     (reemplazá `6.0.1` por la versión que hayas usado si es otra).
   - Texto de la licencia: [https://omnetpp.org/intro/license](https://omnetpp.org/intro/license).

En este repositorio esa información figura en este README; si publicás los binarios en otro sitio (p. ej. solo en Releases), incluir un aviso equivalente en la descripción del release o en un archivo junto a los binarios.

---

## Notes

- **Versión por defecto**: 6.0.1. Es configurable en **todos** los scripts (build, install y tests) con la variable de entorno **`OMNET_VERSION`**, por ejemplo: `OMNET_VERSION=6.0.2 ./build_omnet_deb.sh`.
- **Open Scene Graph (OSG)**: Disabled in the build (`WITH_OSG=no`) to avoid extra dependencies.
- **Python**: The scripts create a `venv` inside the OMNeT++ tree with numpy, pandas, matplotlib, scipy, seaborn and posix_ipc, required by the framework.
