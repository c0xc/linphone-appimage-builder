#!/bin/bash
# Complete build and package workflow for Linphone AppImage
# This script runs INSIDE the container

set -e

BUILD_DIR="${BUILD_DIR:-/build}"
INSTALL_PREFIX="${BUILD_DIR}/install"

echo "========================================"
echo "Linphone Build & Package Workflow"
echo "========================================"
echo ""

# Step 1: Build
if [ ! -f "${BUILD_DIR}/linphone-desktop/build/bin/linphone" ]; then
    echo "Step 1/3: Building Linphone..."
    /usr/local/bin/build-linphone.sh
else
    echo "Step 1/3: Build already exists, skipping..."
fi

# Step 2: Install
echo ""
echo "Step 2/3: Installing Linphone..."
export INSTALL_PREFIX="${INSTALL_PREFIX}"
/usr/local/bin/install-linphone.sh

# Step 3: Package as AppImage
echo ""
echo "Step 3/3: Creating AppImage..."
export INSTALL_PREFIX="${INSTALL_PREFIX}"
/usr/local/bin/package-appimage.sh

echo ""
echo "========================================"
echo "Complete! AppImage ready."
echo "========================================"
