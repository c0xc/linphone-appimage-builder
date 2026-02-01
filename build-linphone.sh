#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QT6_BASE_IMAGE="${QT6_BASE_IMAGE:-qt-6.10.1-fedora}"
IMAGE_NAME="linphone-build-env:fedora-qt6"
CONTAINER_NAME="linphone-build"
BUILD_DIR="/build"

# Safeguard
if [ -f /.dockerenv ] || [ -f /run/.containerenv ] || [ -n "${container:-}" ]; then
    echo "ERROR: Run on HOST, not inside container!"
    exit 1
fi

# Check if base image exists
check_base_image() {
    if ! podman image exists "${QT6_BASE_IMAGE}"; then
        echo "ERROR: Base image ${QT6_BASE_IMAGE} not found!"
        echo "Available images:"
        podman images
        exit 1
    fi
    echo "Found base image: ${QT6_BASE_IMAGE}"
}

# Build the Docker image with dependencies
build_image() {
    echo "Building Linphone build environment image..."
    podman build \
        --target linphone-deps \
        -t "${IMAGE_NAME}" \
        -f "${SCRIPT_DIR}/docker-files/Dockerfile.fedora-qt6" \
        "${SCRIPT_DIR}"
    echo "Image built successfully: ${IMAGE_NAME}"
}

# Remove existing container if present
cleanup_container() {
    if podman ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        echo "Removing existing container ${CONTAINER_NAME}..."
        podman rm -f "${CONTAINER_NAME}" || true
    fi
}

# Run container (without building)
run_container() {
    echo "Starting container ${CONTAINER_NAME}..."
    
    # Check for src directory and mount it readonly if found
    local mount_args=""
    if [ -d "src" ]; then
        echo "Found src directory, mounting readonly to /src"
        mount_args="--volume $(pwd)/src:/src:ro,Z"
    fi
    
    # Create persistent container
    podman run -d \
        --name "${CONTAINER_NAME}" \
        --volume "$(pwd)/build-output:${BUILD_DIR}:Z" \
        ${mount_args} \
        "${IMAGE_NAME}" \
        sleep infinity
    
    echo "Container started"
}

# Drop into interactive shell
interactive_shell() {
    echo ""
    echo "Dropping into container shell..."
    echo "  - Build directory: ${BUILD_DIR}"
    echo "  - To rebuild: /usr/local/bin/build-linphone.sh"
    echo "  - To exit: type 'exit' or press Ctrl+D"
    echo ""
    
    podman exec -it "${CONTAINER_NAME}" \
        env PS1='[\[\033[1;34m\]linphone-build\[\033[0m\]] \u@\h:\w\$ ' \
        /bin/bash
    
    echo "Exited container shell"
}

# Main execution
main() {
    echo "=== Linphone Podman Build Environment (Minimal) ==="
    echo "Base Qt6 image: ${QT6_BASE_IMAGE}"
    echo "Build image: ${IMAGE_NAME}"
    echo "Container: ${CONTAINER_NAME}"
    echo ""
    
    check_base_image
    build_image
    cleanup_container
    run_build
    
    # Check if --no-build flag was passed
    if [[ "${1:-}" == "--no-build" ]]; then
        echo "Skipping build step, jumping into container..."
    else
        echo "Building Linphone inside container..."
        if podman exec "${CONTAINER_NAME}" /usr/local/bin/build-linphone.sh; then
            echo "Build completed successfully!"
        else
            echo "Build failed or incomplete, but dropping into shell for debugging..."
        fi
    fi
    
    interactive_shell
    
    echo ""
    echo "Container ${CONTAINER_NAME} is still running"
    echo "To re-enter: podman exec -it ${CONTAINER_NAME} /bin/bash"
    echo "To stop: podman stop ${CONTAINER_NAME}"
    echo "To remove: podman rm -f ${CONTAINER_NAME}"
}

main "$@"
