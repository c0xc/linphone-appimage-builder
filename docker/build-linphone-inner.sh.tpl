#!/bin/bash
# Minimal Linphone build script for container
# This script runs INSIDE the container

set -e

BUILD_DIR="${BUILD_DIR:-/build}"
SRC_DIR="${SRC_DIR:-/src}"
USE_FORK="${USE_FORK:-}"
FORK_REPO="https://github.com/c0xc/linphone-desktop.git"
OFFICIAL_REPO="https://gitlab.linphone.org/BC/public/linphone-desktop.git"

echo "Building Linphone..."

cd "${BUILD_DIR}"

# Check if linphone-desktop exists in /build, if not check /src, otherwise clone
if [ ! -d "linphone-desktop" ]; then
    if [ -d "${SRC_DIR}/linphone-desktop" ]; then
        echo "Copying linphone-desktop from ${SRC_DIR}..."
        cp -r "${SRC_DIR}/linphone-desktop" .
    else
        if [ "${USE_FORK}" = "true" ] || [ "${USE_FORK}" = "1" ]; then
            echo "Cloning Linphone repository from fork: ${FORK_REPO}..."
            git clone "${FORK_REPO}" linphone-desktop
        else
            echo "Cloning Linphone repository from official source: ${OFFICIAL_REPO}..."
            git clone "${OFFICIAL_REPO}" linphone-desktop
        fi
    fi
else
    echo "Linphone repository already exists at ${BUILD_DIR}/linphone-desktop"
fi

# Enter Linphone source directory
cd linphone-desktop

# Check if this is a git repository
if [ -f .git/config ]; then
    IS_GIT=true
else
    IS_GIT=false
fi

# Initialize git submodules if this is a git repository
if [ "$IS_GIT" = true ]; then
    # If using fork, update .gitmodules to point to fork of linphone-sdk
    if [ "${USE_FORK}" = "true" ] || [ "${USE_FORK}" = "1" ]; then
        echo "Updating .gitmodules to use fork of linphone-sdk..."
        if [ -f .gitmodules ]; then
            sed -i 's|https://gitlab.linphone.org/BC/public/linphone-sdk.git|https://github.com/c0xc/linphone-sdk.git|g' .gitmodules
        fi
    fi

    echo "Initializing git submodules..."
    # Retry logic for submodule initialization (network timeouts)
    for i in {1..3}; do
        if git submodule update --init --recursive; then
            echo "Submodules initialized successfully on attempt $i"
            break
        else
            if [ $i -lt 3 ]; then
                echo "Submodule initialization failed, retrying in 15s... (Attempt $i/3)"
                sleep 15
            else
                echo "ERROR: Submodule initialization failed after 3 attempts"
                exit 1
            fi
        fi
    done
fi

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