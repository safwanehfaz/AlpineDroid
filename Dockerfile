# AlpineDroid Dockerfile
#
# This Dockerfile builds a bootstrap environment for running Alpine Linux on Android.
# It uses a multi-stage build to compile a static proot binary and package it
# with an Alpine Linux minirootfs.

# ==============================================================================
# Stage 1: The Builder
#
# This stage sets up a Debian-based build environment, compiles proot,
# and prepares the necessary binaries for the final package.
# ==============================================================================
FROM debian:latest AS proot-builder

# PROOT_ARCH is the critical build argument that tells the makefile which
# architecture we are cross-compiling for (e.g., 'aarch64', 'arm').
# This is passed in from the build.sh script.
ARG PROOT_ARCH

# Set frontend to noninteractive to prevent apt-get from hanging on user prompts.
ENV DEBIAN_FRONTEND=noninteractive

# Install all necessary build dependencies.
# - We add the i386 architecture to support the 32-bit loader required by termux-proot.
# - build-essential, git, and pkg-config are standard build tools.
# - libtalloc-dev is a required library for proot, installed for both architectures.
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    crossbuild-essential-i386 \
    crossbuild-essential-arm64 \
    crossbuild-essential-armhf \
    git \
    pkg-config \
    libtalloc-dev \
    libtalloc-dev:i386 \
    # nproc is used for parallel builds
    procps && \
    # Clean up apt cache to keep the layer small.
    rm -rf /var/lib/apt/lists/*

# Clone the termux/proot repository. We use a shallow clone (--depth=1)
# because we only need the latest version of the source code.
RUN git config --global http.sslVerify false && \
    git clone https://github.com/termux/proot.git /proot_src

# Set the working directory to the 'src' folder, which contains the GNUmakefile.
WORKDIR /proot_src/src

# Build proot using the official GNUmakefile.
# - We set the CROSS_COMPILE variable to point to the correct toolchain for
#   the target architecture. The makefile will automatically use this to
#   select the right compiler (e.g., aarch64-linux-gnu-gcc).
# - We use -j$(nproc) to parallelize the build and speed it up.
RUN export CROSS_COMPILE=$(case "${PROOT_ARCH}" in \
      "aarch64") echo "aarch64-linux-gnu-" ;; \
      "arm")     echo "arm-linux-gnueabihf-" ;; \
    esac) && \
    make -j$(nproc)

# Install the compiled binaries into a temporary directory for easy copying.
RUN make install DESTDIR=/proot_install

# ==============================================================================
# Stage 2: The Final Package
#
# This stage takes the compiled binaries from the builder stage and packages
# them with a minimal Alpine Linux root filesystem into a zip archive.
# ==============================================================================
FROM alpine:latest

# ARCH is passed from the build.sh script to download the correct rootfs.
ARG ARCH

# Install tools needed for packaging the final artifact.
RUN apk add --no-cache wget zip

WORKDIR /build

# Download the Alpine Linux Mini Root Filesystem for the target architecture.
# Note: Using a specific version (e.g., v3.15) for reproducibility.
RUN wget "https://dl-cdn.alpinelinux.org/alpine/v3.15/releases/${ARCH}/alpine-minirootfs-3.15.0-${ARCH}.tar.gz" -O alpine-rootfs.tar.gz

# Create and extract the root filesystem.
RUN mkdir -p rootfs
RUN tar -xzf alpine-rootfs.tar.gz -C rootfs

# Copy the compiled proot binary and the 32-bit loader from the builder stage
# into the correct location in our new rootfs.
COPY --from=proot-builder /proot_install/bin/proot /build/rootfs/usr/bin/proot
COPY --from=proot-builder /proot_install/bin/loader /build/rootfs/usr/bin/loader
COPY --from=proot-builder /proot_install/bin/loader-m32 /build/rootfs/usr/bin/loader-m32

# Create the final bootstrap.zip archive containing the complete root filesystem.
RUN cd rootfs && zip -r /bootstrap.zip .

# The final command is just a placeholder; the purpose of this stage is to
# produce the bootstrap.zip artifact, which is then extracted by build.sh.
CMD ["echo", "This image was used to build the bootstrap.zip artifact."]