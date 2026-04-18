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
    apt-get install -y --no-install-recommends \
    ca-certificates \
    gnupg \
    build-essential \
    crossbuild-essential-i386 \
    git \
    python3 \
    pkg-config \
    libtalloc-dev \
    libarchive-dev \
    bison \
    flex \
    autoconf \
    libtool \
    libtool-bin \
    gawk && \
    rm -rf /var/lib/apt/lists/*


# Disable SSL verification for git to avoid issues with cloning the repository in environments where SSL certificates may not be properly configured (e.g., CI environments).
RUN git config --global http.sslVerify false && \
    git clone --depth 1 https://github.com/termux/proot.git /proot_src

WORKDIR /proot_src/src

# Build proot using the official GNUmakefile from the 'src' directory.
# V=1 enables verbose output for easier debugging.
RUN make V=1
RUN make install DESTDIR=/proot_install

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
COPY --from=proot-builder /proot_install/bin/proot /build/rootfs/usr/bin/proot

# Create the final bootstrap.zip archive containing the complete root filesystem.
RUN cd rootfs && zip -r /bootstrap.zip .

# The final command is just a placeholder; the purpose of this stage is to produce the bootstrap.zip artifact.
CMD ["echo", "This image was used to build the bootstrap.zip artifact."]
