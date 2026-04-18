# This Makefile is a standalone build script for termux/proot.
# It is designed to be run from the root of the proot source directory.

# Default goal
.DEFAULT_GOAL := all

# Cross-compilation setup
# CROSS_COMPILE can be set, e.g., CROSS_COMPILE=i686-linux-gnu-
CC       ?= $(CROSS_COMPILE)gcc
LD       = $(CC)
STRIP    ?= $(CROSS_COMPILE)strip
OBJCOPY  ?= $(CROSS_COMPILE)objcopy
OBJDUMP  ?= $(CROSS_COMPILE)objdump

# Source directory
SRC := src

# Build flags
CPPFLAGS += -D_FILE_OFFSET_BITS=64 -D_GNU_SOURCE -I. -I$(SRC)
CFLAGS   += -Wall -Wextra -O2 -D__x86_64__
LDFLAGS  += -ltalloc -Wl,-z,noexecstack

# Verbose output control (V=1 for verbose)
V = 0
ifeq ($(V), 0)
    Q = @
else
    Q =
endif

# --- Source Files ---
PROOT_C_SOURCES := \
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
	extension/fix_symlink_size/fix_symlink_size.c

PROOT_OBJECTS := $(patsubst %.c,$(BUILD_DIR)/%.o,$(PROOT_C_SOURCES))
PROOT_OBJECTS += $(BUILD_DIR)/loader/loader-wrapped.o
PROOT_OBJECTS += $(BUILD_DIR)/loader/loader-m32-wrapped.o

# --- Build Targets ---

all: proot

proot: $(BUILD_DIR)/proot

# --- Auto-configuration: build.h ---
# This part generates the build.h file with version info and feature detection.
.PHONY: build.h
build.h:
	$(Q)echo "  GEN   $@"
	$(Q)echo "/* This file is auto-generated, edit at your own risk.  */" > $@
	$(Q)echo "#ifndef BUILD_H" >> $@
	$(Q)echo "#define BUILD_H" >> $@
	$(Q)sh -c 'VERSION=$$(git describe --tags --dirty --abbrev=8 --always 2>/dev/null); if [ ! -z "$${VERSION}" ]; then printf "#undef VERSION\n#define VERSION \"$${VERSION}\"\n"; fi;' >> $@
	$(Q)echo "#endif /* BUILD_H */" >> $@

# --- Main proot binary ---
$(BUILD_DIR)/proot: $(PROOT_OBJECTS)
	$(Q)echo "  LD    $@"
	$(Q)$(LD) -o $@ $^ $(LDFLAGS)

# --- Loader Targets ---
# Defines how to build the 64-bit and 32-bit loaders.
LOADER_ADDRESS_64 := 0x100000
LOADER_ADDRESS_32 := 0x10000

LOADER_CFLAGS_64  := -fPIC -ffreestanding
LOADER_LDFLAGS_64 := -static -nostdlib -Wl,--build-id=none,-Ttext=$(LOADER_ADDRESS_64),--rosegment,-z,noexecstack

LOADER_CFLAGS_32  := -m32 -fPIC -ffreestanding
LOADER_LDFLAGS_32 := -m32 -static -nostdlib -Wl,--build-id=none,-Ttext=$(LOADER_ADDRESS_32),--rosegment,-z,noexecstack

# Rule to build a loader (64 or 32 bit)
define build_loader
.PHONY: $(BUILD_DIR)/loader/loader$1
$(BUILD_DIR)/loader/loader$1: $(BUILD_DIR)/loader/loader$1.o $(BUILD_DIR)/loader/assembly$1.o
	@echo "  LD    $$@"
	$$(CC) $2 -o $$@ $$^ $$(LOADER_LDFLAGS$1)

$(BUILD_DIR)/loader/loader$1.o: $(SRC)/loader/loader.c
	@mkdir -p $$(dir $$@)
	@echo "  CC    $$@"
	$$(CC) $2 $$(CPPFLAGS) $$(LOADER_CFLAGS$1) -MD -c $$< -o $$@

$(BUILD_DIR)/loader/assembly$1.o: $(SRC)/loader/assembly.S
	@mkdir -p $$(dir $$@)
	@echo "  CC    $$@"
	$$(CC) $2 $$(CPPFLAGS) $$(LOADER_CFLAGS$1) -MD -c $$< -o $$@

# Rule to create wrapped loader object file
$(BUILD_DIR)/loader/loader$1-wrapped.o: $(BUILD_DIR)/loader/loader$1
	@echo "  OBJCOPY $$@"
	$$(OBJCOPY) --input-target=binary --output-target=elf64-x86-64 --binary-architecture=i386:x86-64 $$< $$@
endef

# Instantiate loader build rules
$(eval $(call build_loader,,$(LOADER_CFLAGS_64)))
$(eval $(call build_loader,-m32,$(LOADER_CFLAGS_32)))

# --- Generic Compilation Rule ---
# Compiles any .c file from the src directory into the build directory.
$(BUILD_DIR)/%.o: $(SRC)/%.c build.h
	@mkdir -p $(dir $@)
	$(Q)echo "  CC    $@"
	$(Q)$(CC) $(CPPFLAGS) $(CFLAGS) -MD -c $< -o $@

# --- Installation ---
.PHONY: install
install: $(BUILD_DIR)/proot
	@echo "  INSTALL proot"
	@mkdir -p $(DESTDIR)/bin
	@cp $(BUILD_DIR)/proot $(DESTDIR)/bin/proot

# --- Cleanup ---
.PHONY: clean
clean:
	@echo "  CLEAN"
	@rm -rf $(BUILD_DIR) build.h
