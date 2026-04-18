#!/bin/bash
set -e

# Default to aarch64 if no architecture is specified
ARCH=${1:-aarch64}
PLATFORM=""
PROOT_ARCH=""

# Determine platform and proot architecture based on the input
if [ "$ARCH" = "aarch64" ]; then
    PLATFORM="linux/arm64"
    PROOT_ARCH="aarch64"
elif [ "$ARCH" = "armv7l" ] || [ "$ARCH" = "armv7" ]; then
    PLATFORM="linux/arm/v7"
    PROOT_ARCH="arm"
else
    echo "Error: Unsupported architecture '$ARCH'. Use 'aarch64' or 'armv7l'."
    exit 1
fi

echo "Building for architecture: $ARCH with docker buildx"
echo "Platform: $PLATFORM"

# Create a directory for the build output
mkdir -p dist

# Ensure a buildx builder is available and in use.
if ! docker buildx ls | grep -q "mybuilder"; then
    docker buildx create --name mybuilder
fi
docker buildx use mybuilder

# Build the Docker image using buildx, passing the architecture as a build argument
# We use --load to make the image available to the local docker daemon for the next step
docker buildx build \
    --no-cache \
    --platform $PLATFORM \
    --build-arg "ARCH=${ARCH}" \
    --build-arg "PROOT_ARCH=${PROOT_ARCH}" \
    -t "alpinedroid-builder:${ARCH}" \
    --load \
    -f Dockerfile .

# Create a temporary container from the built image
CONTAINER_ID=$(docker create "alpinedroid-builder:${ARCH}")

# Copy the bootstrap.zip from the container to the host
docker cp "${CONTAINER_ID}:/bootstrap.zip" "dist/bootstrap-${ARCH}.zip"

# Remove the temporary container
docker rm "${CONTAINER_ID}"

echo "Build complete!"
echo "Artifact created at: dist/bootstrap-${ARCH}.zip"
