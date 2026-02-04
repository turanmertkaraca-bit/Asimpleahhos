#!/bin/bash
#
# run_qemu_uefi32.sh - Test ASCII-OS in QEMU with 32-bit UEFI firmware
#
# Usage: ./run_qemu_uefi32.sh [iso-file]
#
# This script runs the UEFI application in QEMU using OVMF 32-bit firmware.

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_msg() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Show usage
usage() {
    cat << EOF
Usage: $0 [iso-file]

Run ASCII-OS in QEMU with 32-bit UEFI firmware.

Arguments:
  iso-file    Path to bootable ISO (default: out/ascii-os.iso)

Example:
  $0 out/ascii-os.iso

This will launch QEMU with:
  - 32-bit OVMF UEFI firmware
  - 512MB RAM
  - Serial console output
  - Graphics console

Controls:
  - Use the application as normal
  - Ctrl+Alt+Q or close window to exit QEMU
EOF
}

# Parse arguments
ISO_FILE="${1:-out/ascii-os.iso}"

if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    usage
    exit 0
fi

# Check if ISO exists
if [ ! -f "$ISO_FILE" ]; then
    print_error "ISO file not found: $ISO_FILE"
    echo ""
    echo "Please build the ISO first:"
    echo "  make"
    echo "  ./tools/make_iso_uefi32.sh out/BOOTIA32.EFI out/ascii-os.iso"
    echo ""
    exit 1
fi

# Find OVMF 32-bit firmware
# Try common paths
OVMF_PATHS=(
    "/usr/share/ovmf/OVMF_CODE_IA32.fd"
    "/usr/share/edk2-ovmf/ia32/OVMF_CODE.fd"
    "/usr/share/qemu/ovmf-ia32-code.bin"
    "/usr/share/OVMF/OVMF32_CODE_4M.fd"
    "/usr/share/edk2/ovmf-ia32/OVMF_CODE.fd"
)

OVMF_CODE=""
for path in "${OVMF_PATHS[@]}"; do
    if [ -f "$path" ]; then
        OVMF_CODE="$path"
        break
    fi
done

if [ -z "$OVMF_CODE" ]; then
    print_error "32-bit OVMF firmware not found"
    echo ""
    echo "Searched in:"
    for path in "${OVMF_PATHS[@]}"; do
        echo "  - $path"
    done
    echo ""
    echo "Please install OVMF:"
    echo "  Ubuntu/Debian: sudo apt install ovmf"
    echo "  Fedora: sudo dnf install edk2-ovmf"
    echo ""
    echo "Note: Some distributions only provide 64-bit OVMF."
    echo "For 32-bit UEFI testing, you may need to build OVMF from source"
    echo "or use a compatible alternative firmware."
    exit 1
fi

# Check for QEMU
if ! command -v qemu-system-i386 &> /dev/null; then
    print_error "qemu-system-i386 not found"
    echo ""
    echo "Please install QEMU:"
    echo "  Ubuntu/Debian: sudo apt install qemu-system-x86"
    echo "  Fedora: sudo dnf install qemu-system-x86"
    echo ""
    exit 1
fi

print_msg "Using OVMF firmware: $OVMF_CODE"
print_msg "Booting ISO: $ISO_FILE"
echo ""
print_msg "Starting QEMU..."
echo ""

# Run QEMU with 32-bit UEFI firmware
qemu-system-i386 \
    -bios "$OVMF_CODE" \
    -cdrom "$ISO_FILE" \
    -m 512M \
    -serial stdio \
    -display gtk \
    -vga std \
    -net none \
    "$@"

print_msg "QEMU session ended"
