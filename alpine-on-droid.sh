#!/bin/sh

# Stop on first error
set -e

# The directory where Alpine will be installed
INSTALL_DIR="${HOME}/alpinedroid"
ROOTFS_DIR="${INSTALL_DIR}/rootfs"
ZIP_FILE="bootstrap.zip"

echo "Setting up AlpineDroid environment..."

# Create the installation directory
mkdir -p "${INSTALL_DIR}"
cd "${INSTALL_DIR}"

# Check if the bootstrap zip file exists
if [ ! -f "${ZIP_FILE}" ]; then
    echo "Error: ${ZIP_FILE} not found in the current directory."
    echo "Please place the bootstrap.zip file from the build process in this directory and run the script again."
    exit 1
fi

# Clean up any previous installation
if [ -d "${ROOTFS_DIR}" ]; then
    echo "Removing existing rootfs..."
    rm -rf "${ROOTFS_DIR}"
fi

# Extract the root filesystem
echo "Extracting rootfs from ${ZIP_FILE}..."
unzip -o "${ZIP_FILE}" -d "${ROOTFS_DIR}"

# --- Proot Entrypoint ---
# This is the command that will be run to enter the Alpine environment.
# You can add more proot options here if needed.
PROOT_CMD="proot --link2symlink -0 -r ${ROOTFS_DIR} /usr/bin/env -i HOME=/root TERM=${TERM} /bin/sh --login"

echo "Setup complete. You can now enter the Alpine environment by running:"
echo "${PROOT_CMD}"

# Optional: Automatically start the environment after setup
# echo "Starting Alpine environment..."
# exec ${PROOT_CMD}
