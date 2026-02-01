#!/bin/bash
# Package Linphone as AppImage
# This script runs INSIDE the container
# Requires: install-linphone.sh to have been run first

set -e

BUILD_DIR="${BUILD_DIR:-/build}"
INSTALL_PREFIX="${INSTALL_PREFIX:-/build/install}"
APPIMAGE_DIR="${BUILD_DIR}/AppImage"
OUTPUT_DIR="${BUILD_DIR}/output"

echo "Creating AppImage from ${INSTALL_PREFIX}..."

# Create AppDir structure
APPDIR="${APPIMAGE_DIR}/AppDir"
rm -rf "${APPDIR}"
mkdir -p "${APPDIR}"

# Copy installed files to AppDir
echo "Copying installed files..."
cp -r "${INSTALL_PREFIX}"/* "${APPDIR}/"

# Create AppDir structure
mkdir -p "${APPDIR}/usr"
# Move everything to usr/ if not already there
if [ -d "${APPDIR}/bin" ]; then
    mv "${APPDIR}/bin" "${APPDIR}/usr/" || true
fi
if [ -d "${APPDIR}/lib" ]; then
    mv "${APPDIR}/lib" "${APPDIR}/usr/" || true
fi
if [ -d "${APPDIR}/lib64" ]; then
    mv "${APPDIR}/lib64" "${APPDIR}/usr/" || true
fi
if [ -d "${APPDIR}/share" ]; then
    mv "${APPDIR}/share" "${APPDIR}/usr/" || true
fi

# Create desktop file
cat > "${APPDIR}/linphone.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Linphone
Comment=SIP softphone for voice/video calls and instant messaging
Exec=linphone
Icon=linphone
Categories=Network;Telephony;Qt;
Terminal=false
EOF

# Find and copy icon (look for linphone icon in various locations)
ICON_FOUND=false
for icon_path in \
    "${BUILD_DIR}/linphone-desktop/Linphone/data/icon/hicolor/512x512/apps/icon.png" \
    "${BUILD_DIR}/linphone-desktop/Linphone/data/icon/hicolor/256x256/apps/icon.png" \
    "${BUILD_DIR}/linphone-desktop/assets/icons/hicolor/512x512/apps/linphone.png" \
    "${BUILD_DIR}/linphone-desktop/assets/icons/hicolor/256x256/apps/linphone.png" \
    "${BUILD_DIR}/linphone-desktop/Linphone/assets/images/logo.png" \
    "${APPDIR}/usr/share/icons/hicolor/512x512/apps/linphone.png" \
    "${APPDIR}/usr/share/icons/hicolor/256x256/apps/linphone.png"; do
   if [ -f "$icon_path" ]; then
        cp "$icon_path" "${APPDIR}/linphone.png"
        ICON_FOUND=true
        echo "Found icon at: $icon_path"
        break
    fi
done

if [ "$ICON_FOUND" = false ]; then
    echo "ERROR: No icon found! This should not happen."
    exit 1
fi

# Create AppRun script
cat > "${APPDIR}/AppRun" <<'EOF'
#!/bin/bash
APPDIR="$(dirname "$(readlink -f "$0")")"

# Set up library paths
export LD_LIBRARY_PATH="${APPDIR}/usr/lib:${APPDIR}/usr/lib64:${LD_LIBRARY_PATH}"

# Set Qt plugin path
export QT_PLUGIN_PATH="${APPDIR}/usr/plugins:${QT_PLUGIN_PATH}"
export QML_IMPORT_PATH="${APPDIR}/usr/qml:${QML_IMPORT_PATH}"
export QML2_IMPORT_PATH="${APPDIR}/usr/qml:${QML2_IMPORT_PATH}"

# Execute linphone
exec "${APPDIR}/usr/bin/linphone" "$@"
EOF

chmod +x "${APPDIR}/AppRun"

# Download and extract linuxdeploy tools
echo "Downloading linuxdeploy..."
LINUXDEPLOY_DOWNLOAD="${BUILD_DIR}/linuxdeploy-x86_64.AppImage"
LINUXDEPLOY_QT_DOWNLOAD="${BUILD_DIR}/linuxdeploy-plugin-qt-x86_64.AppImage"

if [ ! -f "${LINUXDEPLOY_DOWNLOAD}" ]; then
    wget -q --show-progress https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage \
        -O "${LINUXDEPLOY_DOWNLOAD}"
    chmod +x "${LINUXDEPLOY_DOWNLOAD}"
fi

if [ ! -f "${LINUXDEPLOY_QT_DOWNLOAD}" ]; then
    echo "Downloading linuxdeploy-plugin-qt..."
    wget -q --show-progress https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage \
        -O "${LINUXDEPLOY_QT_DOWNLOAD}"
    chmod +x "${LINUXDEPLOY_QT_DOWNLOAD}"
fi

# Extract AppImages (containers typically don't have FUSE)
echo "Extracting linuxdeploy tools..."
cd "${BUILD_DIR}"

if [ ! -d "${BUILD_DIR}/linuxdeploy" ]; then
    mkdir -p linuxdeploy-extract
    cd linuxdeploy-extract
    "${LINUXDEPLOY_DOWNLOAD}" --appimage-extract >/dev/null 2>&1
    cd ..
    mv linuxdeploy-extract/squashfs-root "${BUILD_DIR}/linuxdeploy"
    rm -rf linuxdeploy-extract
fi

if [ ! -d "${BUILD_DIR}/linuxdeploy-plugin-qt" ]; then
    mkdir -p linuxdeploy-qt-extract
    cd linuxdeploy-qt-extract
    "${LINUXDEPLOY_QT_DOWNLOAD}" --appimage-extract >/dev/null 2>&1
    cd ..
    mv linuxdeploy-qt-extract/squashfs-root "${BUILD_DIR}/linuxdeploy-plugin-qt"
    rm -rf linuxdeploy-qt-extract
fi

LINUXDEPLOY="${BUILD_DIR}/linuxdeploy/AppRun"
LINUXDEPLOY_QT_PLUGIN="${BUILD_DIR}/linuxdeploy-plugin-qt/AppRun"
export APPIMAGE_EXTRACT_AND_RUN=1

# Set Qt paths for linuxdeploy
export QMAKE=/usr/local/bin/qmake
export QML_SOURCES_PATHS="${BUILD_DIR}/linphone-desktop/Linphone"

# Add Qt6 and Linphone SDK to library search path
export LD_LIBRARY_PATH="/usr/local/lib:/usr/local/lib64:${INSTALL_PREFIX}/lib:${INSTALL_PREFIX}/lib64:${LD_LIBRARY_PATH}"

# Create output directory
mkdir -p "${OUTPUT_DIR}"

# Build AppImage using linuxdeploy
echo "Running linuxdeploy..."
cd "${APPIMAGE_DIR}"

# Manually copy Qt6 libraries and Linphone SDK libraries to AppDir first
# This ensures linuxdeploy can find them
echo "Copying Qt6 and Linphone SDK libraries..."
mkdir -p "${APPDIR}/usr/lib"
cp -rL /usr/local/lib/*.so* "${APPDIR}/usr/lib/" 2>/dev/null || true
cp -rL /usr/local/lib64/*.so* "${APPDIR}/usr/lib/" 2>/dev/null || true
cp -rL "${INSTALL_PREFIX}"/lib/*.so* "${APPDIR}/usr/lib/" 2>/dev/null || true
cp -rL "${INSTALL_PREFIX}"/lib64/*.so* "${APPDIR}/usr/lib/"  2>/dev/null || true

# Copy Qt6 plugins and QML modules
echo "Copying Qt6 plugins and QML modules..."
mkdir -p "${APPDIR}/usr/plugins"
cp -r /usr/local/plugins/* "${APPDIR}/usr/plugins/" 2>/dev/null || true
mkdir -p "${APPDIR}/usr/qml"
cp -r /usr/local/qml/* "${APPDIR}/usr/qml/" 2>/dev/null || true

# Use linuxdeploy to finalize the AppDir (without qt plugin, we already copied everything)
echo "Finalizing AppImage with linuxdeploy..."
if [ "$ICON_FOUND" = true ]; then
    "${LINUXDEPLOY}" \
        --appdir="${APPDIR}" \
        --executable="${APPDIR}/usr/bin/linphone" \
        --desktop-file="${APPDIR}/linphone.desktop" \
        --icon-file="${APPDIR}/linphone.png"
else
    "${LINUXDEPLOY}" \
        --appdir="${APPDIR}" \
        --executable="${APPDIR}/usr/bin/linphone" \
        --desktop-file="${APPDIR}/linphone.desktop"
fi

# Download appimagetool to create the final AppImage
APPIMAGETOOL="${BUILD_DIR}/appimagetool-x86_64.AppImage"
if [ ! -f "${APPIMAGETOOL}" ]; then
    echo "Downloading appimagetool..."
    wget -q --show-progress https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage \
        -O "${APPIMAGETOOL}"
    chmod +x "${APPIMAGETOOL}"
fi

# Extract appimagetool if needed
if [ ! -d "${BUILD_DIR}/appimagetool" ]; then
    cd "${BUILD_DIR}"
    mkdir -p appimagetool-extract
    cd appimagetool-extract
    "${APPIMAGETOOL}" --appimage-extract >/dev/null 2>&1
    cd ..
    mv appimagetool-extract/squashfs-root "${BUILD_DIR}/appimagetool"
    rm -rf appimagetool-extract
fi

# Create the final AppImage
echo "Creating AppImage..."
cd "${BUILD_DIR}"
"${BUILD_DIR}/appimagetool/AppRun" "${APPDIR}" "${OUTPUT_DIR}/Linphone-x86_64.AppImage"

echo ""
echo "============================================"
echo "AppImage created successfully!"
echo "Location: ${OUTPUT_DIR}/Linphone-x86_64.AppImage"
echo "============================================"
echo ""
echo "To extract from container, run on host:"
echo "  podman cp linphone-build:/build/output/Linphone-x86_64.AppImage ."
echo ""
