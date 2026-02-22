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
# Priority: existing directory -> extract tar.gz -> extract tar.xz -> git clone
if [ -d "${SRC_DIR}/linphone-desktop" ]; then
    # Sources already in SRC_DIR, use them
    # they might contain manual patches!
    echo "Copying linphone-desktop from ${SRC_DIR}..."
    cp -r "${SRC_DIR}/linphone-desktop" .
elif ls "${BUILD_DIR}"/linphone-desktop*.tar.gz >/dev/null 2>&1; then
    # Tarball with sources found, extract it (might contain patches)
    TARBALL_FILE=$(ls "${BUILD_DIR}"/linphone-desktop*.tar.gz 2>/dev/null | head -1)
    echo "Extracting linphone-desktop from ${TARBALL_FILE}..."
    tar -xzf "${TARBALL_FILE}" -C "${BUILD_DIR}"
    # Handle tarballs with single top-level directory (e.g., linphone-desktop-6.1.0/)
    EXTRACTED_DIR=$(tar -tzf "${TARBALL_FILE}" | head -1 | cut -f1 -d/)
    if [ -d "${BUILD_DIR}/${EXTRACTED_DIR}" ] && [ "${EXTRACTED_DIR}" != "linphone-desktop" ]; then
        echo "Tarball has top-level dir '${EXTRACTED_DIR}', moving to linphone-desktop..."
        mv "${BUILD_DIR}/${EXTRACTED_DIR}" "${BUILD_DIR}/linphone-desktop"
    fi
    if [ ! -d "linphone-desktop" ]; then
        echo "ERROR: extraction did not create ${BUILD_DIR}/linphone-desktop"
        exit 1
    fi
    TARBALL_FOR_VERSION="${TARBALL_FILE}"
elif ls "${BUILD_DIR}"/linphone-desktop*.tar.xz >/dev/null 2>&1; then
    # Tarball with sources found, extract it (might contain patches)
    TARBALL_FILE=$(ls "${BUILD_DIR}"/linphone-desktop*.tar.xz 2>/dev/null | head -1)
    echo "Extracting linphone-desktop from ${TARBALL_FILE}..."
    tar -xJf "${TARBALL_FILE}" -C "${BUILD_DIR}"
    # Handle tarballs with single top-level directory
    EXTRACTED_DIR=$(tar -tJf "${TARBALL_FILE}" | head -1 | cut -f1 -d/)
    if [ -d "${BUILD_DIR}/${EXTRACTED_DIR}" ] && [ "${EXTRACTED_DIR}" != "linphone-desktop" ]; then
        echo "Tarball has top-level dir '${EXTRACTED_DIR}', moving to linphone-desktop..."
        mv "${BUILD_DIR}/${EXTRACTED_DIR}" "${BUILD_DIR}/linphone-desktop"
    fi
    if [ ! -d "linphone-desktop" ]; then
        echo "ERROR: extraction did not create ${BUILD_DIR}/linphone-desktop"
        exit 1
    fi
    TARBALL_FOR_VERSION="${TARBALL_FILE}"
else
    # Clone from git repository (official or fork)
    echo "Cloning Linphone repository (ref: ${repo_ref}) from: ${repo_url}..."
    # Configure git to always fetch tags
    git config --global fetch.tags true
    # Use --tags to fetch tags alongside shallow clone - required for git describe in CMake
    git clone --branch "${repo_ref}" --depth 1 --tags "${repo_url}" linphone-desktop
    TARBALL_FOR_VERSION=""
fi

# Enter Linphone source directory
cd linphone-desktop

# Configure git to fetch tags by default (only if in a git repo)
if [ -d ".git" ]; then
    git config fetch.tags true
fi

# Unshallow the main linphone-desktop repo - CMake runs git describe from here!
# The bc_compute_full_version function uses CMAKE_CURRENT_SOURCE_DIR which points to linphone-desktop
if [ -d ".git" ]; then
    echo "Unshallowing linphone-desktop repository..."
    git fetch --unshallow 2>/dev/null || echo "Note: linphone-desktop might not be shallow or already has full history"
    echo "Fetching tags for linphone-desktop..."
    git fetch --tags || echo "Note: Could not fetch tags for linphone-desktop"
fi

# Check if linphone-desktop has tags and git describe works
# If not (tarball without .git, or shallow clone without tags), create a version tag
echo "Checking linphone-desktop version info..."
if ! git describe >/dev/null 2>&1; then
    echo "No git version info available, creating version tag..."
    if [ ! -d ".git" ]; then
        # Initialize a minimal git repo for tarball case
        git init -q
        git config user.email "build@local"
        git config user.name "Build"
        git add -A >/dev/null 2>&1 || true
        git commit -q -m "Initial commit (tarball build)"
    fi
    
    # Try to extract version from tarball filename (e.g., linphone-desktop-6.1.0.tar.gz)
    VERSION=""
    if [ -n "${TARBALL_FOR_VERSION}" ]; then
        # Extract version from filename
        VERSION=$(basename "${TARBALL_FOR_VERSION}" | sed -n 's/linphone-desktop-\([0-9][0-9.]*[0-9]\(-[a-zA-Z0-9]*\)\?\)\.tar\.\(gz\|xz\)/\1/p')
        echo "Extracted VERSION: '${VERSION}' from '${TARBALL_FOR_VERSION}'"
    fi

    # Use extracted version or generic timestamp-based version
    if [ -n "${VERSION}" ]; then
        TAG_VERSION="${VERSION}"
        echo "Extracted version from tarball: ${VERSION}"
    else
        # Fallback: try to find version in source files, otherwise use timestamp
        # Check for VERSION file or version in CMakeLists.txt
        if [ -f "VERSION" ]; then
            TAG_VERSION=$(cat VERSION | tr -d '[:space:]')
            echo "Found version in VERSION file: ${TAG_VERSION}"
        elif [ -f "CMakeLists.txt" ]; then
            # Try to extract version from CMakeLists.txt project() or set() commands
            TAG_VERSION=$(grep -i 'set.*VERSION' CMakeLists.txt | head -1 | sed 's/.*"\([0-9][0-9.]*[0-9]\(-[a-zA-Z0-9]*\)\?\)".*/\1/' | head -1)
            if [ -n "${TAG_VERSION}" ]; then
                echo "Found version in CMakeLists.txt: ${TAG_VERSION}"
            fi
        fi
        
        # If still no version, use generic timestamp-based version
        if [ -z "${TAG_VERSION}" ]; then
            TAG_VERSION="0.0.0-$(date +%Y%m%d%H%M%S)"
            echo "No version found, using timestamp: ${TAG_VERSION}"
        fi
    fi

    # Create an annotated tag (message matches official style: no "Version " prefix)
    git tag -a "${TAG_VERSION}" -m "${TAG_VERSION}" 2>/dev/null || \
        git tag -f -a "${TAG_VERSION}" -m "${TAG_VERSION}"
    echo "Created version tag: ${TAG_VERSION}"
fi

# Verify git describe now works
echo "Git version: $(git describe 2>/dev/null || echo 'unknown')"

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

    # Register submodules from .gitmodules file (needed for tarball builds)
    if [ -f .gitmodules ]; then
        echo "Registering submodules from .gitmodules..."
        # Remove empty submodule directories BEFORE git submodule commands (tarball contains placeholders)
        echo "Cleaning empty submodule directories..."
        grep -E '^[\t ]*path[\t ]*=' .gitmodules | while read -r line; do
            path=$(echo "$line" | sed 's/.*=[\t ]*//' | tr -d ' ')
            if [ -d "$path" ]; then
                if [ -z "$(ls -A "$path" 2>/dev/null)" ]; then
                    echo "Removing empty directory: $path"
                    rm -rf "$path"
                else
                    echo "Directory $path exists and is not empty, skipping"
                fi
            fi
        done
        
        # Add and commit .gitmodules so git submodule commands can find it
        git add .gitmodules 2>/dev/null || true
        git commit -q -m "Add .gitmodules" 2>/dev/null || true
        
        # Clone submodules directly (git submodule update doesn't work reliably on fresh repos)
        echo "Cloning submodules directly..."
        while IFS='=' read -r key value; do
            key=$(echo "$key" | sed 's/[\t ]//g')
            value=$(echo "$value" | sed 's/^[\t ]*//' | sed 's/[\t ]*$//')
            if [ "$key" = "path" ]; then
                path="$value"
            elif [[ "$key" == "url" ]] && [ -n "$path" ] && [ ! -d "$path/.git" ]; then
                echo "Cloning $path from $value..."
                mkdir -p "$(dirname "$path")"
                # Clone linphone-sdk without --depth 1 to get nested submodules
                if [[ "$path" == *"linphone-sdk"* ]]; then
                    git clone "$value" "$path" 2>&1 || echo "Failed to clone $path"
                    # Initialize nested submodules for linphone-sdk
                    echo "Initializing nested submodules for $path..."
                    (cd "$path" && git submodule update --init --recursive 2>&1) || echo "Failed to init nested submodules for $path"
                else
                    git clone --depth 1 "$value" "$path" 2>&1 || echo "Failed to clone $path"
                fi
                path=""
            fi
        done < .gitmodules
    else
        echo "WARNING: .gitmodules not found, submodules will not be initialized"
    fi

    echo "Initializing git submodules (nested)..."
    # For nested submodules, use git submodule update --init --recursive
    # This should work now that parent submodules are cloned
    for i in {1..3}; do
        if git submodule update --init --recursive 2>&1; then
            echo "Nested submodules initialized successfully on attempt $i"
            break
        else
            if [ $i -lt 3 ]; then
                echo "Nested submodule initialization failed, retrying in 15s... (Attempt $i/3)"
                sleep 15
            else
                echo "WARNING: Nested submodule initialization failed after 3 attempts"
            fi
        fi
    done

    # Fetch tags for all submodules (required for git describe in CMake)
    echo "Fetching tags for all submodules..."
    git submodule foreach --recursive 'git fetch --tags 2>/dev/null || true'

    # Unshallow linphone-sdk submodule and ensure it has tags
    if [ -d "external/linphone-sdk/.git" ] || [ -f "external/linphone-sdk/.git" ]; then
        echo "Unshallowing linphone-sdk submodule..."
        (cd external/linphone-sdk && git fetch --unshallow 2>/dev/null || true)
        (cd external/linphone-sdk && git fetch --tags 2>/dev/null || true)
    fi
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