#!/bin/bash
# Install Linphone to a prefix (shared between AppImage and Flatpak workflows)
# This script runs INSIDE the container

set -e

BUILD_DIR="${BUILD_DIR:-/build}"
INSTALL_PREFIX="${INSTALL_PREFIX:-/build/install}"

echo "Installing Linphone to ${INSTALL_PREFIX}..."

cd "${BUILD_DIR}/linphone-desktop/build"

# Install to the prefix
cmake --install . --prefix "${INSTALL_PREFIX}"

echo "Installation completed to ${INSTALL_PREFIX}"
echo "Binary location: ${INSTALL_PREFIX}/bin/linphone"
echo "Libraries location: ${INSTALL_PREFIX}/lib*"
