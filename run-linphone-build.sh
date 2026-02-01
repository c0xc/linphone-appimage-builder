#!/bin/bash
# Simple wrapper to build Linphone in Podman container
# Builds multi-stage Dockerfile and drops into shell even on build failure

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
QT6_BASE_IMAGE="${QT6_BASE_IMAGE:-qt-6.10.1-fedora}"
IMAGE_NAME="linphone-build-env:fedora-qt6"
CONTAINER_NAME="linphone-build"
BUILD_DIR="/build"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

info() {
    echo -e "${GREEN}==>${NC} $*"
}

warn() {
    echo -e "${YELLOW}==>${NC} $*"
}

error() {
    echo -e "${RED}==>${NC} $*"
}

# Check if base image exists
check_base_image() {
    if ! podman image exists "${QT6_BASE_IMAGE}"; then
        error "Base image ${QT6_BASE_IMAGE} not found!"
        echo "Available images:"
        podman images
        exit 1
    fi
    info "Found base image: ${QT6_BASE_IMAGE}"
}

# Build the Docker image with dependencies (stage 1)
build_image() {
    info "Building Linphone build environment image..."
    info "This may take a while on first run (installing dependencies)..."
    
    podman build \
        -t "${IMAGE_NAME}" \
        -f "${SCRIPT_DIR}/docker/Dockerfile.fedora-qt6" \
        "${SCRIPT_DIR}"
    
    info "Image built successfully: ${IMAGE_NAME}"
}

# Remove existing container if present
cleanup_container() {
    if podman ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        warn "Removing existing container ${CONTAINER_NAME}..."
        podman rm -f "${CONTAINER_NAME}" || true
    fi
}

# Run container and build Linphone (in foreground)
run_build() {
    info "Starting container ${CONTAINER_NAME} in foreground mode..."
    info "Build will run immediately and you'll see all output in real-time."
    echo ""
    
    # Run container in foreground with interactive terminal
    # Execute build script, then drop into interactive shell
    #--volume "${PWD}/build-output:${BUILD_DIR}:Z" \
    podman run -it \
        --name "${CONTAINER_NAME}" \
        "${IMAGE_NAME}" \
        /bin/bash -c "
            echo '${GREEN}==>${NC} Container started in foreground mode'
            echo '${GREEN}==>${NC} Building Linphone inside container...'
            echo ''
            
            if /usr/local/bin/build-linphone.sh; then
                echo ''
                echo '${GREEN}==>${NC} Build completed successfully!'
            else
                echo ''
                echo '${YELLOW}==>${NC} Build failed or incomplete, but dropping into shell for debugging...'
            fi
            
            echo ''
            echo '${GREEN}==>${NC} Dropping into container shell...'
            echo '  - Build directory: ${BUILD_DIR}'
            echo '  - To rebuild: /usr/local/bin/build-linphone.sh'
            echo '  - To exit: type exit or press Ctrl+D'
            echo ''
            
            # Start interactive shell with custom prompt
            exec /bin/bash --rcfile <(echo 'PS1=\"[\[\033[1;34m\]linphone-build\[\033[0m\]] \u@\h:\w\$ \"')
        "
    
    info "Container has exited"
}

# Drop into interactive shell (no longer needed, integrated into run_build)
interactive_shell() {
    # This function is now a no-op since we integrated the shell into run_build
    return 0
}

# Main execution
main() {
    echo "=== Linphone Podman Build Environment ==="
    echo "Base Qt6 image: ${QT6_BASE_IMAGE}"
    echo "Build image: ${IMAGE_NAME}"
    echo "Container: ${CONTAINER_NAME}"
    echo ""
    
    check_base_image
    build_image
    cleanup_container
    run_build
    interactive_shell
    
    echo ""
    info "Build session complete"
    info "To run again: $0"
    info "To clean up container: podman rm ${CONTAINER_NAME}"
}

main "$@"
