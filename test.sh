#!/bin/bash
#
# test.sh - Verify ASCII-OS repository integrity
#
# This script checks that all required files exist and have proper permissions

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

FAIL_COUNT=0

echo "ASCII-OS Repository Verification"
echo "================================="
echo ""

# Check required files
print_info "Checking required files..."
required_files=(
    "README.md"
    "LICENSE"
    "Makefile"
    "src/main.c"
    "tools/make_iso_uefi32.sh"
    "examples/run_qemu_uefi32.sh"
)

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        print_pass "Found: $file"
    else
        print_fail "Missing: $file"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
done

echo ""

# Check executable permissions
print_info "Checking executable permissions..."
exec_files=(
    "tools/make_iso_uefi32.sh"
    "examples/run_qemu_uefi32.sh"
)

for file in "${exec_files[@]}"; do
    if [ -x "$file" ]; then
        print_pass "Executable: $file"
    else
        print_fail "Not executable: $file"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
done

echo ""

# Check file sizes (sanity check)
print_info "Checking file sizes..."

if [ -f "src/main.c" ]; then
    size=$(wc -l < src/main.c)
    if [ $size -gt 500 ]; then
        print_pass "main.c has $size lines (expected >500)"
    else
        print_fail "main.c has only $size lines (expected >500)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
fi

if [ -f "README.md" ]; then
    size=$(wc -l < README.md)
    if [ $size -gt 200 ]; then
        print_pass "README.md has $size lines (expected >200)"
    else
        print_fail "README.md has only $size lines (expected >200)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
fi

echo ""

# Check Makefile targets
print_info "Checking Makefile targets..."
if grep -q "^all:" Makefile; then
    print_pass "Makefile has 'all' target"
else
    print_fail "Makefile missing 'all' target"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

if grep -q "^clean:" Makefile; then
    print_pass "Makefile has 'clean' target"
else
    print_fail "Makefile missing 'clean' target"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

echo ""

# Check for key components in main.c
print_info "Checking main.c components..."
components=(
    "efi_main"
    "app_notepad"
    "app_calc"
    "app_editor"
    "app_donut"
    "draw_topbar"
    "draw_window"
    "read_key"
)

for comp in "${components[@]}"; do
    if grep -q "$comp" src/main.c; then
        print_pass "Found function/component: $comp"
    else
        print_fail "Missing function/component: $comp"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
done

echo ""
echo "================================="
if [ $FAIL_COUNT -eq 0 ]; then
    print_pass "All checks passed!"
    echo ""
    echo "Next steps:"
    echo "  1. make          - Build the project"
    echo "  2. make check    - Verify dependencies"
    echo ""
    exit 0
else
    print_fail "Failed $FAIL_COUNT check(s)"
    exit 1
fi
