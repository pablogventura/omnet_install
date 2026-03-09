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

### Test AppImage in Ubuntu 22.04 (Docker)

To check that the AppImage has SWT libs and runs in a clean Ubuntu 22.04 environment:

```bash
./test_appimage_docker.sh
# Or with an explicit path:
./test_appimage_docker.sh ./dist/OMNeT++-6.0.1-x86_64.AppImage
```

Requires Docker. The script runs the AppImage inside an `ubuntu:22.04` container and verifies that `usr/lib` contains SWT libs, then runs `opp_run --version`.

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
├── install_omnet.sh        # Direct installation
├── build_omnet_deb.sh      # Build .deb package
├── build_omnet_appimage.sh # Build AppImage
├── test_appimage_docker.sh # Test AppImage in Ubuntu 22.04 (Docker)
├── .gitignore
└── README.md
```

---

## Notes

- **Default version**: 6.0.1 (configurable via `OMNET_VERSION` in the build scripts).
- **Open Scene Graph (OSG)**: Disabled in the build (`WITH_OSG=no`) to avoid extra dependencies.
- **Python**: The scripts create a `venv` inside the OMNeT++ tree with numpy, pandas, matplotlib, scipy, seaborn and posix_ipc, required by the framework.
