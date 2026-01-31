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
        --target linphone-deps \
        -t "${IMAGE_NAME}" \
        -f "${SCRIPT_DIR}/Dockerfile.fedora-qt6" \
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

# Run container and build Linphone
run_build() {
    info "Starting container ${CONTAINER_NAME}..."
    
    # Create persistent container
    podman run -d \
        --name "${CONTAINER_NAME}" \
        --volume "${PWD}/build-output:${BUILD_DIR}:Z" \
        "${IMAGE_NAME}" \
        sleep infinity
    
    info "Container started"
    
    # Execute build inside container (continue even on failure)
    info "Building Linphone inside container..."
    if podman exec "${CONTAINER_NAME}" /usr/local/bin/build-linphone.sh; then
        info "Build completed successfully!"
    else
        warn "Build failed or incomplete, but dropping into shell for debugging..."
    fi
}

# Drop into interactive shell
interactive_shell() {
    echo ""
    info "Dropping into container shell..."
    echo "  - Build directory: ${BUILD_DIR}"
    echo "  - To rebuild: /usr/local/bin/build-linphone.sh"
    echo "  - To exit: type 'exit' or press Ctrl+D"
    echo ""
    
    podman exec -it "${CONTAINER_NAME}" \
        env PS1='[\[\033[1;34m\]linphone-build\[\033[0m\]] \u@\h:\w\$ ' \
        /bin/bash
    
    info "Exited container shell"
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
    info "Container ${CONTAINER_NAME} is still running"
    info "To re-enter: podman exec -it ${CONTAINER_NAME} /bin/bash"
    info "To stop: podman stop ${CONTAINER_NAME}"
    info "To remove: podman rm -f ${CONTAINER_NAME}"
}

main "$@"
