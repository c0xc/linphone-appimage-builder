# Linphone Build Script for Podman

This script builds Linphone desktop application inside a Podman container, ensuring **no dependencies are installed on the host system**. All operations happen inside the container.

## Important

**This script ONLY manages containers. It does NOT modify the host system.**
- All dependencies are installed inside the container
- All builds happen inside the container
- The host system remains unchanged

## Features

- **Containerized builds**: All dependencies and build artifacts stay in the container
- **Incremental builds**: Container persists between runs, so you can modify source and rebuild without reinstalling dependencies
- **Configurable base image**: Set `BASE_IMAGE` environment variable to use a different base image
- **Workspace mounting**: Set `WORKSPACE` environment variable to mount a directory to `/build` in the container
- **Easy rebuild**: After entering the container, use `rebuild-linphone` command to rebuild
- **Clean separation**: Each operation is in its own script file for clarity

## Script Structure

- `build-linphone.sh` - Main script (runs on host, manages containers)
- `install-deps.sh` - Installs dependencies (runs inside container)
- `build-linphone-inner.sh` - Builds Linphone (runs inside container)
- `rebuild-linphone-inner.sh` - Rebuilds Linphone (runs inside container)
- `setup-container-env.sh` - Sets up container environment (runs inside container)

## Requirements

- Podman installed and configured
- Base image: `qt-6.4-fedora-36:latest` (or set `BASE_IMAGE` environment variable)

## Usage

### Basic usage

```bash
./build-linphone.sh
```

### With workspace mounting

```bash
export WORKSPACE=/path/to/your/workspace
./build-linphone.sh
```

The workspace directory will be mounted to `/build` inside the container.

### Using a different base image

```bash
export BASE_IMAGE=your-qt-image:tag
./build-linphone.sh
```

### First run

On the first run, the script will:
1. Create a container named `linphone-build` from the base image
2. Install all build dependencies
3. Clone the Linphone repository (if not already present)
4. Build Linphone
5. Drop you into an interactive shell

### Subsequent runs

On subsequent runs, the script will:
1. Reuse the existing container (with all dependencies already installed)
2. Rebuild Linphone (or continue from previous build)
3. Drop you into an interactive shell

### Rebuilding inside the container

Once inside the container, you can rebuild Linphone using:

```bash
rebuild-linphone
```

Or:

```bash
/usr/local/bin/rebuild-linphone.sh
```

Or manually:

```bash
cd /build/linphone-desktop/build
cmake --build . --parallel
```

## Container Management

The container is named `linphone-build` and persists between script runs. To remove it:

```bash
podman rm -f linphone-build
```

To start/stop the container manually:

```bash
podman start linphone-build
podman stop linphone-build
```

To enter the container without running the build:

```bash
podman exec -it linphone-build /bin/bash
```

## Safeguards

The script includes a safeguard that prevents it from running inside a container. It must be run on the host system to properly manage Podman containers.
