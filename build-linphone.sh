#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_IMAGE="${BASE_IMAGE:-qt-6.4-fedora-36:latest}"
CONTAINER_NAME="linphone-build"
BUILD_DIR="/build"

# Safeguard
if [ -f /.dockerenv ] || [ -f /run/.containerenv ] || [ -n "${container:-}" ]; then
    echo "ERROR: Run on HOST, not inside container!"
    exit 1
fi

# Setup container
setup_container() {
    # Remove existing
    podman rm -f "${CONTAINER_NAME}" 2>/dev/null || true
    
    # Create with optional workspace mount
    local mount_args=""
    [ -n "${WORKSPACE:-}" ] && [ -d "$WORKSPACE" ] && mount_args="--volume $WORKSPACE:$BUILD_DIR:Z"
    
    podman create --name "${CONTAINER_NAME}" -it ${mount_args} "${BASE_IMAGE}" /bin/bash
    podman start "${CONTAINER_NAME}"
    
    # Copy and install scripts
    podman exec "${CONTAINER_NAME}" mkdir -p /usr/local/bin
    for script in install-deps build-linphone-inner rebuild-linphone-inner setup-container-env; do
        podman cp "${SCRIPT_DIR}/${script}.sh.tpl" "${CONTAINER_NAME}:/usr/local/bin/${script}.sh"
        podman exec "${CONTAINER_NAME}" chmod +x "/usr/local/bin/${script}.sh"
    done
    
    # Setup env and install deps
    podman exec "${CONTAINER_NAME}" /usr/local/bin/setup-container-env.sh /usr/local/bin/rebuild-linphone-inner.sh
    podman exec "${CONTAINER_NAME}" /usr/local/bin/install-deps.sh
}

# Main
if ! podman ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    setup_container
else
    podman start "${CONTAINER_NAME}" 2>/dev/null || true
fi

# Build (continue on error)
podman exec "${CONTAINER_NAME}" /usr/local/bin/build-linphone-inner.sh || true

# Interactive shell
echo "Dropping into container (run: rebuild-linphone-inner.sh)"
podman exec -it "${CONTAINER_NAME}" env PS1='[linphone-build] \u@\h:\w\$ ' /bin/bash
