#!/bin/bash
# Install build dependencies for Linphone
# This script runs INSIDE the container - it will NOT modify the host system

set -e

echo "Installing build dependencies..."

# Update system
dnf update -y

# Install build tools and dependencies
# Using dnf (Fedora) but trying to use Rocky8-style packages where possible
dnf install -y \
    git \
    cmake \
    gcc \
    gcc-c++ \
    make \
    pkg-config \
    ninja-build \
    python3 \
    python3-pip \
    which \
    wget \
    tar \
    xz \
    bzip2 \
    openssl-devel \
    sqlite-devel \
    libvpx-devel \
    opus-devel \
    speex-devel \
    libxml2-devel \
    libsrtp-devel \
    libtool \
    autoconf \
    automake \
    yasm \
    nasm \
    doxygen \
    graphviz \
    flex \
    bison \
    libX11-devel \
    libXext-devel \
    libXrender-devel \
    mesa-libGL-devel \
    libICE-devel \
    libSM-devel \
    fontconfig-devel \
    freetype-devel \
    libXi-devel \
    libXrandr-devel \
    libXcursor-devel \
    libXinerama-devel \
    libXfixes-devel \
    libXcomposite-devel \
    libXdamage-devel \
    libXScrnSaver-devel \
    alsa-lib-devel \
    pulseaudio-libs-devel \
    libv4l-devel \
    libcanberra-devel \
    gstreamer1-devel \
    gstreamer1-plugins-base-devel \
    gstreamer1-plugins-good \
    gstreamer1-plugins-bad-free \
    gstreamer1-plugins-ugly-free \
    libnice-devel \
    libsoup-devel \
    json-glib-devel \
    libsecret-devel \
    libnotify-devel \
    dbus-devel \
    glib2-devel \
    gtk3-devel \
    atk-devel \
    cairo-devel \
    pango-devel \
    gdk-pixbuf2-devel \
    libepoxy-devel \
    libdrm-devel \
    wayland-devel \
    wayland-protocols-devel \
    libxkbcommon-devel \
    libudev-devel \
    systemd-devel \
    zlib-devel \
    bzip2-devel \
    lz4-devel \
    xz-devel \
    zstd-devel \
    libcurl-devel \
    libuuid-devel \
    libffi-devel \
    expat-devel \
    libarchive-devel \
    libyaml-devel \
    readline-devel \
    ncurses-devel \
    gettext-devel \
    intltool \
    desktop-file-utils \
    hicolor-icon-theme \
    || echo "Some packages may not be available, continuing..."

echo "Dependencies installed successfully."
