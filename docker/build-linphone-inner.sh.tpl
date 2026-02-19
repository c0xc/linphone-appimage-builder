#!/bin/bash
# Minimal Linphone build script for container
# This script runs INSIDE the container

set -e

# Environment
BUILD_DIR="${BUILD_DIR:-/build}"
SRC_DIR="${SRC_DIR:-/src}"
USE_FORK="${USE_FORK:-}"
FORK_REPO="https://github.com/c0xc/linphone-desktop.git"
OFFICIAL_REPO="https://gitlab.linphone.org/BC/public/linphone-desktop.git"
# Git repo url (for git clone, only if sources not found)
if [ "${USE_FORK}" = "true" ] || [ "${USE_FORK}" = "1" ]; then
    repo_url="${FORK_REPO}" # USE_FORK
else
    repo_url="${OFFICIAL_REPO}" # Official BC repo (default)
fi
repo_ref="${LINPHONE_REF:-master}"

echo "Building Linphone..."

cd "${BUILD_DIR}"

# Locate or obtain linphone-desktop source:
# Priority: existing directory -> copy from SRC_DIR -> extract tar.gz -> extract tar.xz -> git clone
if [ -d "${SRC_DIR}/linphone-desktop" ]; then
    # Sources already in SRC_DIR, use them
    # they might contain manual patches!
    echo "Copying linphone-desktop from ${SRC_DIR}..."
    cp -r "${SRC_DIR}/linphone-desktop" .
elif [ -f "${BUILD_DIR}/linphone-desktop.tar.gz" ]; then
    # Tarball with sources found, extract it (might contain patches)
    echo "Extracting linphone-desktop from ${BUILD_DIR}/linphone-desktop.tar.gz..."
    tar -xzf "${BUILD_DIR}/linphone-desktop.tar.gz" -C "${BUILD_DIR}"
    if [ ! -d "linphone-desktop" ]; then
        echo "ERROR: extraction did not create ${BUILD_DIR}/linphone-desktop"
        exit 1
    fi
elif [ -f "${BUILD_DIR}/linphone-desktop.tar.xz" ]; then
    # Tarball with sources found, extract it (might contain patches)
    echo "Extracting linphone-desktop from ${BUILD_DIR}/linphone-desktop.tar.xz..."
    tar -xJf "${BUILD_DIR}/linphone-desktop.tar.xz" -C "${BUILD_DIR}"
    if [ ! -d "linphone-desktop" ]; then
        echo "ERROR: extraction did not create ${BUILD_DIR}/linphone-desktop"
        exit 1
    fi
else
    # Clone from git repository (official or fork)
    echo "Cloning Linphone repository (branch: ${repo_ref}) from: ${repo_url}..."
    git clone --branch "${repo_ref}" --depth 1 "${repo_url}" linphone-desktop
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