#!/bin/bash
# Minimal Linphone build script for container
# This script runs INSIDE the container

set -e

BUILD_DIR="${BUILD_DIR:-/build}"
SRC_DIR="${SRC_DIR:-/src}"

echo "Building Linphone..."

cd "${BUILD_DIR}"

# Check if linphone-desktop exists in /build, if not check /src, otherwise clone
if [ ! -d "linphone-desktop" ]; then
    if [ -d "${SRC_DIR}/linphone-desktop" ]; then
        echo "Copying linphone-desktop from ${SRC_DIR}..."
        cp -r "${SRC_DIR}/linphone-desktop" .
    else
        echo "Cloning Linphone repository..."
        git clone https://gitlab.linphone.org/BC/public/linphone-desktop.git
    fi
else
    echo "Linphone repository already exists at ${BUILD_DIR}/linphone-desktop"
fi

cd linphone-desktop

# Create build directory
mkdir -p build
cd build

# Configure and build
echo "Configuring Linphone..."
cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DENABLE_QT6=ON \
    -DENABLE_VIDEO=ON \
    -DENABLE_UNIT_TESTS=OFF

echo "Building Linphone..."
cmake --build . --parallel $(nproc)

echo "Build completed successfully!"