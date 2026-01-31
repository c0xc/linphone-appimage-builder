#!/bin/bash
# Build Linphone desktop application
# This script runs INSIDE the container - it will NOT modify the host system

set -e

BUILD_DIR="${BUILD_DIR:-/build}"

echo "Building Linphone..."

cd "${BUILD_DIR}"

# Clone Linphone if not already present
if [ ! -d "linphone-desktop" ]; then
    echo "Cloning Linphone repository..."
    git clone https://gitlab.linphone.org/BC/public/linphone-desktop.git
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
