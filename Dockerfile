# Use a multi-stage build to keep the final image small and clean
# Stage 1: Build a static proot binary
FROM debian:latest AS proot-builder

# Set the frontend to noninteractive to avoid installation prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y \
    build-essential \
    gcc-i686-linux-gnu \
    libc6-dev:i386 \
    git \
    libtalloc-dev \
    libarchive-dev \
    autoconf \
    bison \
    flex \
    texinfo \
    help2man \
    libtool \
    libtool-bin \
    pkg-config \
    gawk

# Clone the proot repository
RUN git clone https://github.com/termux/proot.git /proot_src

WORKDIR /proot_src

# Build proot using the correct two-step process
RUN make -C src loader.elf build.h
RUN make -C src proot
RUN make -C src install PREFIX=/usr DESTDIR=/proot_install

# Stage 2: Create the final bootstrap package
FROM alpine:latest

ARG ARCH
ARG PROOT_ARCH

# Install tools needed for packaging
RUN apk add --no-cache wget zip

WORKDIR /build

# Download the Alpine Mini Root Filesystem
RUN wget "https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/${ARCH}/alpine-minirootfs-3.23.4-${ARCH}.tar.gz" -O alpine-rootfs.tar.gz

# Create the rootfs directory
RUN mkdir -p rootfs

# Extract the rootfs
RUN tar -xzf alpine-rootfs.tar.gz -C rootfs

# Copy the proot binary from the builder stage
COPY --from=proot-builder /proot_install/usr/bin/proot /build/rootfs/usr/bin/proot

# Create the bootstrap.zip
RUN cd rootfs && zip -r /bootstrap.zip .

# The final image doesn't need to contain anything, we just need to build the zip
CMD ["echo", "This image was used to build the bootstrap.zip artifact."]
