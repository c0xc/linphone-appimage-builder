#!/bin/bash
# This script runs inside the container for easy rebuilding of Linphone

set -euo pipefail

BUILD_DIR="${BUILD_DIR:-/build}"
LINPHONE_DIR="${BUILD_DIR}/linphone-desktop"
BUILD_SUBDIR="${LINPHONE_DIR}/build"

echo "=== Rebuilding Linphone ==="

if [ ! -d "${LINPHONE_DIR}" ]; then
    echo "ERROR: Linphone source not found at ${LINPHONE_DIR}"
    echo "Please clone the repository first or set BUILD_DIR correctly."
    exit 1
fi

cd "${LINPHONE_DIR}"

# Update source if it's a git repo
if [ -d .git ]; then
    echo "Updating source from git..."
    git pull || echo "Git pull failed, continuing with existing source..."
fi

# Create build directory if it doesn't exist
mkdir -p "${BUILD_SUBDIR}"
cd "${BUILD_SUBDIR}"

# Reconfigure if CMakeCache.txt doesn't exist
if [ ! -f CMakeCache.txt ]; then
    echo "Configuring Linphone..."
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DENABLE_QT6=ON \
        -DENABLE_VIDEO=ON \
        -DENABLE_UNIT_TESTS=OFF
fi

# Build
echo "Building Linphone..."
cmake --build . --parallel $(nproc)

echo ""
echo "=== Build completed successfully! ==="
echo "Binary location: ${BUILD_SUBDIR}/OUTPUT/"
