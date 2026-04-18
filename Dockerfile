# Use a multi-stage build to keep the final image small and clean
# Stage 1: Build a static proot binary
# Use Debian as the build environment because it has a rich set of pre-compiled development tools.
FROM debian:latest AS proot-builder

# Set the frontend to noninteractive to avoid installation prompts during package installation.
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies for both 64-bit (native) and 32-bit (i386) architectures.
# This is required because the Termux version of proot builds a 32-bit loader (`loader-m32`).
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y \
    # Essential tools for compiling C/C++ code.
    build-essential \
    # Provides a full cross-compilation toolchain for the i386 architecture.
    crossbuild-essential-i386 \
    # A specific 32-bit C compiler.
    gcc-i686-linux-gnu \
    # The 32-bit version of the standard C development library.
    libc6-dev:i386 \
    # For cloning the source code from GitHub.
    git \
    # A required dependency for proot, installed for both architectures.
    libtalloc-dev \
    # The 32-bit version of the talloc library, needed for building the 32-bit loader.
    libtalloc-dev:i386 \
    # Another required dependency for proot, installed for both architectures.
    libarchive-dev \
    # Tools required for the autogen/configure process.
    autoconf \
    bison \
    flex \
    texinfo \
    help2man \
    libtool \
    libtool-bin \
    pkg-config \
    gawk \
    # Python is used by some build scripts.
    python3 \
    # Multilib support to allow building both 64-bit and 32-bit binaries in the same environment.
    gcc-multilib

# Clone the Termux fork of the proot repository, which is optimized for Android environments.
RUN git clone https://github.com/termux/proot.git /proot_src

WORKDIR /proot_src

# Build proot using the specific multi-step process required by this fork.
# V=1 enables verbose output for easier debugging.
# 1. Generate the build.h configuration file.
RUN make -C src build.h V=1
# 2. Build the 64-bit and 32-bit loaders.
RUN make -C src loader/loader loader/loader-m32 V=1
# 3. Build the main proot binary.
RUN make -C src proot V=1
# 4. Install the compiled files into a temporary directory for easy copying later.
RUN make -C src install PREFIX=/usr DESTDIR=/proot_install

# Stage 2: Create the final bootstrap package
# Use a minimal Alpine image for the final packaging stage.
FROM alpine:latest

# Arguments passed from the build script to specify the target architecture.
ARG ARCH
ARG PROOT_ARCH

# Install tools needed for packaging the final artifact.
RUN apk add --no-cache wget zip

WORKDIR /build

# Download the Alpine Mini Root Filesystem for the target architecture.
RUN wget "https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/${ARCH}/alpine-minirootfs-3.23.4-${ARCH}.tar.gz" -O alpine-rootfs.tar.gz

# Create the directory to hold the filesystem.
RUN mkdir -p rootfs

# Extract the downloaded rootfs into the directory.
RUN tar -xzf alpine-rootfs.tar.gz -C rootfs

# Copy ONLY the compiled proot binary from the first build stage into the Alpine rootfs.
# This is the magic of multi-stage builds; none of the Debian build environment is included.
COPY --from=proot-builder /proot_install/usr/bin/proot /build/rootfs/usr/bin/proot

# Create the final bootstrap.zip archive containing the complete root filesystem.
RUN cd rootfs && zip -r /bootstrap.zip .

# The final command is just a placeholder; the purpose of this stage is to produce the bootstrap.zip artifact.
CMD ["echo", "This image was used to build the bootstrap.zip artifact."]
