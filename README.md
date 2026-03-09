# OMNeT++ Install — Installation and packaging scripts

Scripts to install and package **OMNeT++ 6.3.0** on Linux (Debian/Ubuntu): direct installation, `.deb` package, or portable **AppImage**.

[OMNeT++](https://omnetpp.org/) is a discrete event simulation framework for networks and systems.

---

## Summary of options

| Option | Script | Result |
|--------|--------|--------|
| **Direct installation** | `install_omnet.sh` | OMNeT++ built and installed in the current directory |
| **.deb package** | `build_omnet_deb.sh` | Installable `.deb` package in `/opt/omnetpp-6.3.0` |
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

- OMNeT++ is in `./omnetpp-6.3.0/`
- Application menu shortcuts are created
- To use from terminal: `source omnetpp-6.3.0/setenv` then `omnetpp` or `opp_run`
- If the IDE does not appear in PATH, open a new terminal or launch **OMNeT++** from the applications menu

---

## Option 2: .deb package

Builds a `.deb` package that installs OMNeT++ in `/opt/omnetpp-6.3.0` and adds the `omnetpp` and `opp_run` commands to PATH (no need for `source setenv`).

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

**Build the .deb in Docker (recommended for testing on 22.04 and 24.04):**  
If you build the .deb on a host with a newer glibc (e.g. Ubuntu 24.04), the package may not run on Ubuntu 22.04. To get a .deb that works on **both** versions, build it inside an Ubuntu 22.04 container:

```bash
./build_omnet_deb_docker.sh
# Or with output directory:
./build_omnet_deb_docker.sh ./dist
```

Requires Docker. First run takes ~15–30 min (image download, dependencies and compilation).

### Installing the generated package

```bash
sudo dpkg -i omnetpp_6.3.0-1_amd64.deb
# If dependencies are missing:
sudo apt-get install -f
```

After installation:

- OMNeT++ in `/opt/omnetpp-6.3.0`
- Commands in PATH: `omnetpp` (IDE), `opp_run` (simulator)

### Environment variables (build)

- **`OMNET_VERSION`**: OMNeT++ version (default: `6.3.0`)
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

**Build the AppImage in Docker (compatible with Ubuntu 22.04 and 24.04):**  
For the AppImage to work on **Ubuntu 22.04** (and thus on 24.04 too), build it inside an Ubuntu 22.04 container; if built on a host with a newer glibc, it may fail on 22.04.

```bash
./build_omnet_appimage_docker.sh
# Or with output directory:
./build_omnet_appimage_docker.sh ./dist
```

Requires Docker. First run takes ~20–40 min.

### Running the AppImage

```bash
# Open the IDE
./OMNeT++-6.3.0-x86_64.AppImage

# Run simulations from the console
./OMNeT++-6.3.0-x86_64.AppImage opp_run [options]
./OMNeT++-6.3.0-x86_64.AppImage run [options]
```

On first IDE launch, the AppImage copies OMNeT++ to `~/.local/share/omnetpp-6.3.0` for writable workspace, logs, etc.

### AppImage troubleshooting

- **First run**: The IDE copy to `~/.local/share/omnetpp-6.3.0` can take a moment; subsequent launches are faster.
- **"Could not load SWT library"** (e.g. on Ubuntu 22.04): The build script copies SWT native libs into the AppImage’s `usr/lib`. After building, the script prints how many `libswt-pi4*.so` files are in `usr/lib`; if that count is 0, the IDE may fail. Run the AppImage with **`DEBUG_OMNET_APPIMAGE=1`** to print paths and config (e.g. `DEBUG_OMNET_APPIMAGE=1 ./OMNeT++-6.3.0-x86_64.AppImage`).
- **Other native errors** (e.g. missing symbols, GLIBC version): SWT depends on GTK/glibc on the host; document the distro and error for support. For maximum portability, the target distro should be similar to the build distro.

### Environment variables (build)

- **`OMNET_VERSION`**: OMNeT++ version (default: `6.3.0`)
- **`BUILD_DIR`**: Temporary build directory
- **`CLEAN_BUILD`**: If set, the build directory is removed when finished

### Environment variables (runtime)

- **`DEBUG_OMNET_APPIMAGE=1`**: Print APPDIR, WRITABLE_OMNET, eclipse.ini presence and SWT lib count before launching the IDE (for troubleshooting).

### Testing with Docker (Ubuntu 22.04 and 24.04)

All three delivery methods can be tested inside **Ubuntu 22.04 or 24.04** containers. Requires Docker. By default `test_all_docker.sh` runs each test on both versions.

| Test | Script | What it does |
|------|--------|---------------|
| **Installer** | `test_install_docker.sh [22.04\|24.04]` | Runs `install_omnet.sh` in the container (download + build, 15–30 min), then checks `opp_run --version` and `bin/omnetpp`. |
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

### GUI tests (verify the IDE launches)

To verify that the OMNeT++ IDE opens correctly (not just `opp_run`), use **`test_gui_docker.sh`** in two ways:

| Mode | Description |
|------|-------------|
| **`--x11`** | The OMNeT++ window opens on **your screen**. Requires X11 (or Wayland with Xwayland) and on the host run once: `xhost +local:docker`. |
| **`--browser`** | Starts a **desktop in a container** and serves it via **noVNC**. Open **http://localhost:6901** in your browser to see the desktop; open a terminal or launcher and run OMNeT++ to check that the IDE loads. |
| **`--browser-check`** | Same as `--browser` but the script runs an **automatic check**: it launches the IDE in the container, waits and uses `wmctrl` to verify a window with "OMNeT" in the title appeared. Useful for CI or to avoid manual browser checks. |

Examples:

```bash
# Desktop in browser (open http://localhost:6901 and run OMNeT++ manually)
./test_gui_docker.sh --browser ./OMNeT++-6.3.0-x86_64.AppImage

# Automatic check: script reports OK or FAIL based on whether it detects the window
./test_gui_docker.sh --browser-check

# With .deb (installs .deb in container and leaves desktop ready to run omnetpp)
./test_gui_docker.sh --browser .deb ./omnetpp_6.3.0-1_amd64.deb

# Window on your screen (X11)
./test_gui_docker.sh --x11 ./OMNeT++-6.3.0-x86_64.AppImage
```

For `--browser` and `--browser-check` the image **accetto/ubuntu-vnc-xfce-g3** (Ubuntu + Xfce + noVNC) is used. Default user/password: **headless** / **headless**.

---

## Build dependencies (options 2 and 3)

The scripts `build_omnet_deb.sh` and `build_omnet_appimage.sh` can install build dependencies with the **`-d`** or **`--install-deps`** option. The Docker build scripts (`build_omnet_deb_docker.sh`, `build_omnet_appimage_docker.sh`) install the same deps inside the container.

- build-essential, clang, lld, gdb, bison, flex, perl, **pkg-config**
- **Qt6** (qt6-base-dev, libqt6opengl6-dev) for OMNeT++ 6.2+; Qt5 (qtbase5-dev, qt5-qmake, libqt5opengl5-dev) kept for compatibility
- libxml2-dev, zlib1g-dev, doxygen, graphviz, xdg-utils
- Python3 and venv: numpy, scipy, matplotlib, pandas, seaborn, posix_ipc; for 6.2+ the scripts also install **`python/requirements.txt`** from the OMNeT++ source (e.g. ipython) so `configure` passes
- mpi-default-dev, libstdc++-12-dev
- libwebkit2gtk (optional, for the IDE)

If you build **without** Docker, install Qt6 (and pkg-config) on your system when targeting OMNeT++ 6.3.0; otherwise `configure` will fail with "Could not find moc, rcc, and uic for Qt6" or "pkg-config program not found".

---

## Repository structure

```
.
├── .github/workflows/
│   └── check-omnet-release.yml   # Daily: create an issue when omnetpp/omnetpp has a new release (verify scripts)
├── install_omnet.sh         # Direct installation
├── build_omnet_deb.sh       # Build .deb package
├── build_omnet_deb_docker.sh    # Build .deb inside Ubuntu 22.04 Docker (for 22.04 + 24.04)
├── build_omnet_appimage.sh      # Build AppImage
├── build_omnet_appimage_docker.sh # Build AppImage inside Ubuntu 22.04 Docker (for 22.04 + 24.04)
├── test_install_docker.sh   # Test install script in Ubuntu 22.04/24.04 (Docker)
├── test_deb_docker.sh       # Test .deb install in Ubuntu 22.04/24.04 (Docker)
├── test_appimage_docker.sh  # Test AppImage in Ubuntu 22.04/24.04 (Docker)
├── test_all_docker.sh       # Run all Docker tests
├── test_gui_docker.sh       # GUI test: --x11 (window on your screen) or --browser/--browser-check (noVNC)
├── .gitignore
└── README.md
```

---

## License and binary redistribution

**OMNeT++** is under the [Academic Public License (APL)](https://omnetpp.org/intro/license): free for **non-commercial** use (academic, teaching, research, personal use). Commercial use requires a license from [OMNEST](https://www.omnest.com/).

You may **share** the `.deb` and AppImage produced by this repo (e.g. on GitHub Releases) without violating the license, provided that:

1. **Use is non-commercial only** (recipients must also use them under the APL).
2. **Accompany the binaries** with this information:
   - That OMNeT++ is under the **Academic Public License**.
   - **Source code** for the version used: from the official project, e.g. for 6.3.0:  
     [https://github.com/omnetpp/omnetpp/releases/tag/omnetpp-6.3.0](https://github.com/omnetpp/omnetpp/releases/tag/omnetpp-6.3.0)  
     (replace `6.3.0` with the version you used if different).
   - License text: [https://omnetpp.org/intro/license](https://omnetpp.org/intro/license).

In this repository that information is in this README; if you publish the binaries elsewhere (e.g. only in Releases), include an equivalent notice in the release description or in a file next to the binaries.

---

## Notes

- **Default version**: 6.3.0. Configurable in **all** scripts (build, install and tests) via the **`OMNET_VERSION`** environment variable, e.g. `OMNET_VERSION=6.0.1 ./build_omnet_deb.sh`.
- **OMNeT++ 6.2+ (e.g. 6.3.0)** needs **Qt6** (qt6-base-dev), **pkg-config**, and Python packages from the source tree’s `python/requirements.txt` (e.g. ipython). The scripts handle this when you use the `-d` option or the Docker build scripts.
- **Open Scene Graph (OSG)**: Disabled in the build (`WITH_OSG=no`) to avoid extra dependencies.
- **Python**: The scripts create a `venv` inside the OMNeT++ tree with numpy, pandas, matplotlib, scipy, seaborn and posix_ipc; for 6.2+ they also install from `python/requirements.txt` so the IDE/configure checks pass.
- **New OMNeT++ releases**: The workflow [Check OMNeT++ release](.github/workflows/check-omnet-release.yml) runs daily and opens an issue when [omnetpp/omnetpp](https://github.com/omnetpp/omnetpp) publishes a new release, so you can verify the scripts with that version. You can also trigger it manually from the Actions tab.
