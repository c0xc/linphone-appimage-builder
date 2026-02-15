# Linphone AppImage Build Container

This is an unofficial build container for Linphone.
It creates AppImage files which should run on most modern Linux desktop installations without installation.

## Details

I'm using Podman locally. I use Podman instead of Docker, whenever possible.

## Requirements

- Podman installed and configured
- Base image: `qt-6.4-fedora-36:latest` by c0xc (or set `BASE_IMAGE` environment variable)

## Usage

### Basic usage

```bash
./build-linphone.sh
```

### With workspace mounting

```bash
WORKSPACE=~/tmp/ ./build-linphone.sh
```

The workspace directory will be mounted to `/build` inside the container.

### Rebuilding inside the container

Fix things inside the container:

```bash
rebuild-linphone
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

## Author

Philip Seeger (philip@c0xc.net)
