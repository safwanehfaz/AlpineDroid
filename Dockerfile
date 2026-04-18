# Stage 1: Build a static proot binary
FROM debian:latest AS proot-builder

ENV DEBIAN_FRONTEND=noninteractive

# Install only the essential dependencies for building proot.
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    gcc-i686-linux-gnu \
    libc6-dev:i386 \
    git \
    libtalloc-dev \
    libtalloc-dev:i386 && \
    rm -rf /var/lib/apt/lists/*

# Clone the proot source code.
RUN git config --global http.sslVerify false && \
    git clone https://github.com/termux/proot.git /proot_src

WORKDIR /proot_src/src

# Define the list of source files for proot.
# This bypasses the complex GNUmakefile and gives us direct control.
ENV PROOT_SOURCES=" \
    cli/cli.c \
    cli/proot.c \
    cli/note.c \
    execve/enter.c \
    execve/exit.c \
    execve/shebang.c \
    execve/elf.c \
    execve/ldso.c \
    execve/auxv.c \
    execve/aoxp.c \
    path/binding.c \
    path/glue.c \
    path/canon.c \
    path/f2fs-bug.c \
    path/path.c \
    path/proc.c \
    path/temp.c \
    syscall/seccomp.c \
    syscall/syscall.c \
    syscall/chain.c \
    syscall/enter.c \
    syscall/exit.c \
    syscall/sysnum.c \
    syscall/socket.c \
    syscall/heap.c \
    syscall/rlimit.c \
    tracee/tracee.c \
    tracee/mem.c \
    tracee/reg.c \
    tracee/event.c \
    tracee/seccomp.c \
    tracee/statx.c \
    ptrace/ptrace.c \
    ptrace/user.c \
    ptrace/wait.c \
    extension/extension.c \
    extension/ashmem_memfd/ashmem_memfd.c \
    extension/kompat/kompat.c \
    extension/fake_id0/chown.c \
    extension/fake_id0/chroot.c \
    extension/fake_id0/getsockopt.c \
    extension/fake_id0/sendmsg.c \
    extension/fake_id0/socket.c \
    extension/fake_id0/open.c \
    extension/fake_id0/unlink.c \
    extension/fake_id0/rename.c \
    extension/fake_id0/chmod.c \
    extension/fake_id0/utimensat.c \
    extension/fake_id0/access.c \
    extension/fake_id0/exec.c \
    extension/fake_id0/link.c \
    extension/fake_id0/symlink.c \
    extension/fake_id0/mk.c \
    extension/fake_id0/stat.c \
    extension/fake_id0/helper_functions.c \
    extension/fake_id0/fake_id0.c \
    extension/hidden_files/hidden_files.c \
    extension/mountinfo/mountinfo.c \
    extension/port_switch/port_switch.c \
    extension/sysvipc/sysvipc.c \
    extension/sysvipc/sysvipc_msg.c \
    extension/sysvipc/sysvipc_sem.c \
    extension/sysvipc/sysvipc_shm.c \
    extension/link2symlink/link2symlink.c \
    extension/fix_symlink_size/fix_symlink_size.c"

# Generate the script.h header file required by the loader.
RUN gcc -o loader/script loader/script.c && ./loader/script > loader/script.h

# Compile the 32-bit loader directly.
RUN i686-linux-gnu-gcc -static -fPIC -ffreestanding \
    -o loader-m32 loader/loader.c loader/assembly.S \
    -Wl,-Ttext=0x10000,--rosegment,-z,noexecstack

# Compile the main proot binary directly, linking all sources.
# This command explicitly defines the architecture and includes all necessary flags.
RUN gcc -o proot $PROOT_SOURCES \
    -D_FILE_OFFSET_BITS=64 -D_GNU_SOURCE -D__x86_64__ \
    -I. -I./ \
    -Wall -Wextra -O2 \
    -ltalloc -Wl,-z,noexecstack

# Create an installation directory.
RUN mkdir -p /proot_install/usr/bin

# Copy the compiled binaries to the installation directory.
RUN cp proot /proot_install/usr/bin/proot
RUN cp loader-m32 /proot_install/usr/bin/loader-m32

# Stage 2: Create the final bootstrap package
FROM alpine:latest

ARG ARCH

RUN apk add --no-cache wget zip

WORKDIR /build

RUN wget "https://dl-cdn.alpinelinux.org/alpine/v3.15/releases/${ARCH}/alpine-minirootfs-3.15.0-${ARCH}.tar.gz" -O alpine-rootfs.tar.gz

RUN mkdir -p rootfs
RUN tar -xzf alpine-rootfs.tar.gz -C rootfs

# Copy the compiled proot and loader binaries from the builder stage.
COPY --from=proot-builder /proot_install/usr/bin/proot /build/rootfs/usr/bin/proot
COPY --from=proot-builder /proot_install/usr/bin/loader-m32 /build/rootfs/usr/bin/loader-m32

RUN cd rootfs && zip -r /bootstrap.zip .

CMD ["echo", "This image was used to build the bootstrap.zip artifact."]