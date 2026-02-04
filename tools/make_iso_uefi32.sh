#!/bin/bash
#
# make_iso_uefi32.sh - Create bootable UEFI 32-bit ISO image
#
# Usage: ./make_iso_uefi32.sh <BOOTIA32.EFI> <output.iso>
#
# This script creates an ISO9660 filesystem with El Torito UEFI boot
# support for 32-bit UEFI systems.

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print colored message
print_msg() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Show usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS] <BOOTIA32.EFI> <output.iso>

Create a bootable UEFI 32-bit ISO image.

Arguments:
  BOOTIA32.EFI    Path to the UEFI application binary
  output.iso      Path for the output ISO file

Options:
  --dry-run       Show what would be done without creating ISO
  --help          Show this help message

Example:
  $0 out/BOOTIA32.EFI out/ascii-os.iso

The resulting ISO can be:
  - Tested in QEMU with 32-bit OVMF firmware
  - Written to USB drive with dd (dd if=output.iso of=/dev/sdX)
  - Booted on 32-bit UEFI hardware

Safety: This script only creates an ISO file. It never writes to
        block devices automatically.
EOF
}

# Parse arguments
DRY_RUN=0
BOOTIA32_EFI=""
OUTPUT_ISO=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            if [ -z "$BOOTIA32_EFI" ]; then
                BOOTIA32_EFI="$1"
            elif [ -z "$OUTPUT_ISO" ]; then
                OUTPUT_ISO="$1"
            else
                print_error "Too many arguments"
                usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate arguments
if [ -z "$BOOTIA32_EFI" ] || [ -z "$OUTPUT_ISO" ]; then
    print_error "Missing required arguments"
    echo ""
    usage
    exit 1
fi

# Check if input file exists
if [ ! -f "$BOOTIA32_EFI" ]; then
    print_error "Input file not found: $BOOTIA32_EFI"
    echo ""
    echo "Did you build the UEFI application first?"
    echo "Run: make"
    echo ""
    echo "Expected file location: out/BOOTIA32.EFI"
    exit 1
fi

# Check for required tools
if ! command -v xorriso &> /dev/null; then
    print_error "xorriso not found"
    echo ""
    echo "Please install xorriso:"
    echo "  Ubuntu/Debian: sudo apt install xorriso"
    echo "  Fedora: sudo dnf install xorriso"
    echo ""
    exit 1
fi

# Create temporary directory for ISO contents
ISO_ROOT=$(mktemp -d -t ascii-os-iso.XXXXXX)

print_msg "Creating ISO directory structure in: $ISO_ROOT"

# Create EFI directory structure
mkdir -p "$ISO_ROOT/EFI/BOOT"

# Copy BOOTIA32.EFI to the correct location
cp "$BOOTIA32_EFI" "$ISO_ROOT/EFI/BOOT/BOOTIA32.EFI"

print_msg "Copied $BOOTIA32_EFI -> $ISO_ROOT/EFI/BOOT/BOOTIA32.EFI"

# Create a simple README on the ISO
cat > "$ISO_ROOT/README.txt" << 'EOF'
ASCII-OS UEFI Application

This ISO contains a bootable 32-bit UEFI application that provides
a text-based operating system environment.

Boot this ISO on:
  - 32-bit UEFI systems
  - QEMU with 32-bit OVMF firmware
  - VirtualBox with EFI enabled

The application uses only UEFI boot services and does not require
an operating system kernel.

File location: EFI/BOOT/BOOTIA32.EFI
EOF

print_msg "Added README.txt to ISO"

# Show directory tree in dry-run mode
if [ $DRY_RUN -eq 1 ]; then
    print_msg "DRY RUN - ISO directory tree:"
    echo ""
    tree "$ISO_ROOT" 2>/dev/null || find "$ISO_ROOT" -print
    echo ""
    print_msg "Would create ISO: $OUTPUT_ISO"
    print_msg "Clean up temporary directory: $ISO_ROOT"
    rm -rf "$ISO_ROOT"
    exit 0
fi

# Create the ISO image using xorriso
print_msg "Creating bootable ISO image: $OUTPUT_ISO"

xorriso -as mkisofs \
    -R -J \
    -e EFI/BOOT/BOOTIA32.EFI \
    -no-emul-boot \
    -V "ASCII_OS" \
    -o "$OUTPUT_ISO" \
    "$ISO_ROOT" 2>&1 | grep -v "NOTE" || true

# Clean up
rm -rf "$ISO_ROOT"

# Verify the ISO was created
if [ -f "$OUTPUT_ISO" ]; then
    ISO_SIZE=$(du -h "$OUTPUT_ISO" | cut -f1)
    print_msg "Successfully created ISO image: $OUTPUT_ISO ($ISO_SIZE)"
    echo ""
    echo "Next steps:"
    echo "  1. Test in QEMU: ./examples/run_qemu_uefi32.sh $OUTPUT_ISO"
    echo "  2. Write to USB: sudo dd if=$OUTPUT_ISO of=/dev/sdX bs=4M status=progress"
    echo "     (Replace /dev/sdX with your USB device - BE CAREFUL!)"
    echo ""
else
    print_error "Failed to create ISO image"
    exit 1
fi

exit 0
