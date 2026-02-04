# Makefile for ASCII-OS UEFI Application (32-bit)
#
# This builds a 32-bit UEFI PE/COFF executable (BOOTIA32.EFI)
# using the GNU-EFI library and toolchain.

# Output directory
OUT_DIR = out

# Target binary
TARGET = $(OUT_DIR)/BOOTIA32.EFI

# Source files
SRC = src/main.c
OBJ = $(OUT_DIR)/main.o

# Compiler and linker
CC = gcc
LD = ld
OBJCOPY = objcopy

# Architecture
ARCH = ia32
ARCH_DIR = i386

# Common GNU-EFI paths (try multiple locations)
# Ubuntu/Debian typical paths
GNUEFI_LIBDIR_1 = /usr/lib/gnu-efi
GNUEFI_LIBDIR_2 = /usr/lib
GNUEFI_LIBDIR_3 = /usr/lib32

# Include paths
GNUEFI_INCDIR = /usr/include/efi
GNUEFI_INCARCH = $(GNUEFI_INCDIR)/$(ARCH_DIR)

# Find the correct library directory
GNUEFI_LIBDIR := $(shell \
	if [ -d "$(GNUEFI_LIBDIR_1)" ]; then echo "$(GNUEFI_LIBDIR_1)"; \
	elif [ -d "$(GNUEFI_LIBDIR_2)" ]; then echo "$(GNUEFI_LIBDIR_2)"; \
	elif [ -d "$(GNUEFI_LIBDIR_3)" ]; then echo "$(GNUEFI_LIBDIR_3)"; \
	else echo "NOT_FOUND"; fi)

# CRT objects and linker script
CRT0 = $(GNUEFI_LIBDIR)/crt0-efi-$(ARCH).o
LDSCRIPT = $(GNUEFI_LIBDIR)/elf_$(ARCH)_efi.lds

# Compiler flags for 32-bit UEFI
CFLAGS = -m32 \
         -Wall \
         -Wextra \
         -O2 \
         -fno-stack-protector \
         -fno-strict-aliasing \
         -fpic \
         -fshort-wchar \
         -mno-red-zone \
         -DEFI_FUNCTION_WRAPPER \
         -I$(GNUEFI_INCDIR) \
         -I$(GNUEFI_INCARCH)

# Linker flags
LDFLAGS = -nostdlib \
          -znocombreloc \
          -T $(LDSCRIPT) \
          -shared \
          -Bsymbolic \
          -L$(GNUEFI_LIBDIR) \
          $(CRT0)

# Libraries
LIBS = -lefi -lgnuefi

# Build targets
.PHONY: all clean check help

all: check-deps $(TARGET)
	@echo ""
	@echo "Build complete! Output: $(TARGET)"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Create bootable ISO: ./tools/make_iso_uefi32.sh $(TARGET) $(OUT_DIR)/ascii-os.iso"
	@echo "  2. Test in QEMU: ./examples/run_qemu_uefi32.sh $(OUT_DIR)/ascii-os.iso"
	@echo ""

# Check dependencies before building
check-deps:
	@echo "Checking build dependencies..."
	@if [ "$(GNUEFI_LIBDIR)" = "NOT_FOUND" ]; then \
		echo "ERROR: GNU-EFI libraries not found!"; \
		echo ""; \
		echo "Please install GNU-EFI:"; \
		echo "  Ubuntu/Debian: sudo apt install gnu-efi gcc-multilib"; \
		echo "  Fedora: sudo dnf install gnu-efi-devel gcc"; \
		echo ""; \
		exit 1; \
	fi
	@if [ ! -f "$(CRT0)" ]; then \
		echo "ERROR: CRT0 object not found: $(CRT0)"; \
		echo "Please install gnu-efi package"; \
		exit 1; \
	fi
	@if [ ! -f "$(LDSCRIPT)" ]; then \
		echo "ERROR: Linker script not found: $(LDSCRIPT)"; \
		echo "Please install gnu-efi package"; \
		exit 1; \
	fi
	@if ! $(CC) -m32 -E - < /dev/null > /dev/null 2>&1; then \
		echo "ERROR: 32-bit compiler support not available"; \
		echo ""; \
		echo "Please install 32-bit libraries:"; \
		echo "  Ubuntu/Debian: sudo apt install gcc-multilib"; \
		echo "  Fedora: sudo dnf install glibc-devel.i686"; \
		echo ""; \
		exit 1; \
	fi
	@if [ ! -d "$(GNUEFI_INCDIR)" ]; then \
		echo "ERROR: GNU-EFI headers not found at $(GNUEFI_INCDIR)"; \
		echo "Please install gnu-efi package"; \
		exit 1; \
	fi
	@echo "All dependencies found!"
	@echo "  - GNU-EFI lib: $(GNUEFI_LIBDIR)"
	@echo "  - CRT0: $(CRT0)"
	@echo "  - Linker script: $(LDSCRIPT)"
	@echo ""

# Create output directory
$(OUT_DIR):
	mkdir -p $(OUT_DIR)

# Compile source to object file
$(OBJ): $(SRC) | $(OUT_DIR)
	@echo "Compiling $(SRC)..."
	$(CC) $(CFLAGS) -c $< -o $@

# Link to create shared object
$(OUT_DIR)/main.so: $(OBJ)
	@echo "Linking shared object..."
	$(LD) $(LDFLAGS) $(OBJ) -o $@ $(LIBS)

# Convert shared object to UEFI PE/COFF executable
$(TARGET): $(OUT_DIR)/main.so
	@echo "Creating UEFI executable..."
	$(OBJCOPY) -j .text -j .sdata -j .data \
	           -j .dynamic -j .dynsym -j .rel \
	           -j .rela -j .reloc -j .eh_frame \
	           --target=efi-app-$(ARCH) $< $@
	@echo "Created: $(TARGET)"

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(OUT_DIR)
	@echo "Clean complete!"

# Help target
help:
	@echo "ASCII-OS Build System"
	@echo ""
	@echo "Targets:"
	@echo "  make          - Build BOOTIA32.EFI (default)"
	@echo "  make clean    - Remove build artifacts"
	@echo "  make check    - Check dependencies only"
	@echo "  make help     - Show this help message"
	@echo ""
	@echo "Requirements:"
	@echo "  - GNU-EFI development files"
	@echo "  - GCC with 32-bit support"
	@echo "  - binutils (ld, objcopy)"
	@echo ""
	@echo "Install on Ubuntu/Debian:"
	@echo "  sudo apt install gnu-efi gcc-multilib"
	@echo ""

# Alias for check-deps
check: check-deps
