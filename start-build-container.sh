#!/bin/bash
# Start the Linphone build container and run a build session.

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
QT6_BASE_IMAGE="${QT6_BASE_IMAGE:-qt-6.10.1-fedora}"
IMAGE_NAME="linphone-build-env:fedora-qt6"
CONTAINER_NAME="linphone-build"
BUILD_DIR="/build"
WORKSPACE="${WORKSPACE:-}"

# Use podman by default
CTR="${CTR:-podman}"

# Detect Podman (Docker fallback is for build pipeline)
if [ "${CTR}" = "podman" ] && ! command -v podman >/dev/null 2>&1; then
    CTR="docker"
fi
if ! command -v "${CTR}" >/dev/null 2>&1; then
    echo "ERROR: container runtime not found (tried: podman, docker)." >&2
    echo "Install podman, or set CTR=podman|docker explicitly." >&2
    exit 1
fi

VOLUME_SUFFIX=""
if [ "${CTR}" = "podman" ]; then
    VOLUME_SUFFIX=":Z"
fi

info() {
    echo "$*"
}

warn() {
    echo "WARNING: $*" >&2
}

error() {
    echo "ERROR: $*" >&2
}

image_exists() {
    local image_ref="$1"
    if [ "${CTR}" = "podman" ]; then
        podman image exists "${image_ref}"
        return $?
    fi

    docker image inspect "${image_ref}" >/dev/null 2>&1
}

container_exists() {
    local name="$1"
    if [ "${CTR}" = "podman" ]; then
        podman ps -a --format "{{.Names}}" | grep -q "^${name}$"
        return $?
    fi

    docker ps -a --format "{{.Names}}" | grep -q "^${name}$"
}

check_base_image() {
    if image_exists "${QT6_BASE_IMAGE}"; then
        info "Found base image: ${QT6_BASE_IMAGE}"
        return 0
    fi
    
    if image_exists "localhost/${QT6_BASE_IMAGE}"; then
        QT6_BASE_IMAGE="localhost/${QT6_BASE_IMAGE}"
        info "Found base image: ${QT6_BASE_IMAGE}"
        return 0
    fi

    local ghcr_image="ghcr.io/c0xc/${QT6_BASE_IMAGE}"
    warn "Base image not found locally, trying ${ghcr_image}..."
    
    if "${CTR}" pull "${ghcr_image}"; then
        "${CTR}" tag "${ghcr_image}" "${QT6_BASE_IMAGE}"
        info "Pulled and tagged: ${ghcr_image} -> ${QT6_BASE_IMAGE}"
        return 0
    fi

    # If the ghcr fallback failed, try a common alternative naming scheme.
    # Example: local tag `qt-6.10.1-fedora` -> remote `ghcr.io/c0xc/qt6-fedora:6.10.1`
    if [[ "${QT6_BASE_IMAGE}" =~ ^qt-([0-9]+\.[0-9]+\.[0-9]+)-fedora$ ]]; then
        local ver="${BASH_REMATCH[1]}"
        local alt="ghcr.io/c0xc/qt6-fedora:${ver}"
        info "Fallback: trying alternative GHCR name ${alt}..."
        if "${CTR}" pull "${alt}"; then
            "${CTR}" tag "${alt}" "${QT6_BASE_IMAGE}" >/dev/null 2>&1 || true
            info "Pulled and tagged: ${alt} -> ${QT6_BASE_IMAGE}"
            return 0
        fi
    fi

    error "Base image ${QT6_BASE_IMAGE} not found locally or on ghcr.io/c0xc"
    exit 1
}

# Build the Docker image with dependencies (stage 1)
build_image() {
    info "Building Linphone build environment image..."
    info "This may take a while on first run (installing dependencies)..."

    "${CTR}" build \
        --build-arg QT6_BASE_IMAGE="${QT6_BASE_IMAGE}" \
        -t "${IMAGE_NAME}" \
        -f "${SCRIPT_DIR}/docker/Dockerfile.fedora-qt6" \
        "${SCRIPT_DIR}"

    info "Image built successfully: ${IMAGE_NAME}"
}

# Remove existing container if present
cleanup_container() {
    if container_exists "${CONTAINER_NAME}"; then
        warn "Removing existing container ${CONTAINER_NAME}..."
        "${CTR}" rm -f "${CONTAINER_NAME}" || true
    fi
}

# Run container and build Linphone (in foreground)
run_build() {
    info "Starting container ${CONTAINER_NAME}..."
    info "Build runs immediately; shell opens afterwards."
    echo ""

    # Run container in foreground with interactive terminal
    # Execute build script, then drop into interactive shell
    local mount_args=()
    if [ -n "${WORKSPACE}" ]; then
        mount_args+=(--volume "${WORKSPACE}:${BUILD_DIR}${VOLUME_SUFFIX}")
    fi

    "${CTR}" run -it \
        --name "${CONTAINER_NAME}" \
        "${mount_args[@]}" \
        "${IMAGE_NAME}" \
        /bin/bash -c "
            echo 'Container started'
            echo 'Building Linphone...'
            echo ''

            if /usr/local/bin/build-linphone.sh; then
                echo ''
                echo 'Build completed successfully'
            else
                echo ''
                echo 'WARNING: Build failed or incomplete, but dropping into shell for debugging...'
            fi

            echo ''
            echo 'Dropping into shell'
            echo '  - Build directory: ${BUILD_DIR}'
            echo '  - To rebuild: /usr/local/bin/build-linphone.sh'
            echo '  - To exit: type exit or press Ctrl+D'
            echo ''

            exec /bin/bash
        "

    info "Container has exited"
}

main() {
    echo "=== Linphone Build Environment ==="
    echo "Runtime: ${CTR}"
    echo "Base Qt6 image: ${QT6_BASE_IMAGE}"
    echo "Build image: ${IMAGE_NAME}"
    echo "Container: ${CONTAINER_NAME}"
    if [ -n "${WORKSPACE}" ]; then
        echo "Workspace mount: ${WORKSPACE} -> ${BUILD_DIR}"
    fi
    echo ""

    if image_exists "${IMAGE_NAME}"; then
        info "Build image already exists: ${IMAGE_NAME} (skipping rebuild)"
    else
        check_base_image
        build_image
    fi
    cleanup_container
    run_build

    echo ""
    info "Build session complete"
    info "To run again: $0"
    info "To clean up container: ${CTR} rm ${CONTAINER_NAME}"
}

main "$@"
