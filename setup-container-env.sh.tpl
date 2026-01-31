#!/bin/bash
# Setup container environment (bashrc, aliases, etc.)
# This script runs INSIDE the container - it will NOT modify the host system

set -e

CONTAINER_BUILD_SCRIPT="${1:-/usr/local/bin/rebuild-linphone.sh}"

# Add alias and message to bashrc for easy access
cat >> ~/.bashrc << EOF

# Linphone build helper
alias rebuild-linphone="${CONTAINER_BUILD_SCRIPT}"
echo "To rebuild Linphone, run: rebuild-linphone (or ${CONTAINER_BUILD_SCRIPT})"
EOF

echo "Container environment configured."
