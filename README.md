# ASCII-OS: A TempleOS-Inspired 32-bit UEFI Application

ASCII-OS is a self-contained, bootable UEFI application that provides a text-based operating system environment. It runs directly on UEFI firmware without requiring a traditional OS kernel.

## Features

- **Pure ASCII/Unicode Text UI** - Box-drawing characters and text-only interface
- **Built-in Applications**:
  - **Notepad** - Multi-line text editor with save/load capability
  - **Calculator** - Expression evaluator for basic arithmetic
  - **Editor** - File editor for sample.txt with F3 reload
  - **Donut** - Rotating ASCII art animation
- **Cursor Navigation** - Arrow keys move a crosshair overlay
- **UEFI File System Support** - Save/load files when supported by firmware
- **Graceful Fallback** - Works even without filesystem support

## System Requirements

### Build Host (Linux/WSL)
- Ubuntu 20.04+ or Debian 11+ (WSL2 supported)
- GCC with 32-bit support
- GNU-EFI development files
- xorriso for ISO creation
- QEMU for testing (optional)

### Target System
- 32-bit UEFI firmware
- No OS required - boots directly as UEFI application
- Works on legacy 32-bit tablets, some Atom-based systems

## Quick Start

### 1. Install Dependencies (Ubuntu/Debian/WSL)

```bash
sudo apt update
sudo apt install -y \
    build-essential \
    gnu-efi \
    gcc-multilib \
    xorriso \
    qemu-system-x86 \
    ovmf
```

### 2. Build the UEFI Application

```bash
make
```

This produces `out/BOOTIA32.EFI`, a 32-bit UEFI PE/COFF executable.

### 3. Create Bootable ISO

```bash
./tools/make_iso_uefi32.sh out/BOOTIA32.EFI out/ascii-os.iso
```

### 4. Test in QEMU

```bash
./examples/run_qemu_uefi32.sh out/ascii-os.iso
```

**Note**: 32-bit OVMF firmware is less common than 64-bit. If not available, see [Testing on Real Hardware](#testing-on-real-hardware) below.

## Detailed Build Instructions

### Understanding the Build Process

The build process creates a UEFI application in several steps:

1. **Compile** - Convert C source to 32-bit object file
2. **Link** - Create shared object using GNU-EFI linker script
3. **Convert** - Transform ELF shared object to PE/COFF format

The Makefile handles all of this automatically.

### Build Targets

```bash
make          # Build BOOTIA32.EFI (default)
make clean    # Remove build artifacts
make check    # Verify dependencies only
make help     # Show help message
```

### Troubleshooting Build Issues

#### Error: "GNU-EFI libraries not found"

```bash
sudo apt install gnu-efi
```

#### Error: "32-bit compiler support not available"

```bash
sudo apt install gcc-multilib
```

On some systems you may also need:
```bash
sudo apt install libc6-dev-i386
```

#### Custom GNU-EFI Installation Path

If GNU-EFI is installed in a non-standard location, edit the `Makefile` and update these variables:

```makefile
GNUEFI_INCDIR = /path/to/efi/include
GNUEFI_LIBDIR = /path/to/efi/lib
```

### Building on Other Platforms

#### Fedora/RHEL

```bash
sudo dnf install gnu-efi-devel gcc glibc-devel.i686 xorriso qemu-system-x86
make
```

#### Arch Linux

```bash
sudo pacman -S gnu-efi gcc-multilib xorriso qemu
make
```

#### Windows (MSYS2)

GNU-EFI can be built in MSYS2, but Linux/WSL is recommended for easier setup.

## Testing on Real Hardware

### Booting from USB Drive

1. Format a USB drive as FAT32
2. Create the directory structure:
   ```
   /EFI/BOOT/
   ```
3. Copy `out/BOOTIA32.EFI` to `/EFI/BOOT/BOOTIA32.EFI` on the USB drive

4. Boot the target system:
   - Enter BIOS/UEFI firmware setup (usually F2, F12, or Del during boot)
   - Ensure "UEFI Boot" is enabled
   - Disable "Secure Boot" if enabled
   - Boot from the USB drive

### Alternative: Write ISO to USB

```bash
# WARNING: This will erase all data on /dev/sdX!
# Replace /dev/sdX with your actual USB device (e.g., /dev/sdb)
sudo dd if=out/ascii-os.iso of=/dev/sdX bs=4M status=progress
sync
```

**IMPORTANT**: Double-check the device name! Using the wrong device will destroy data.

### Compatible Hardware

- 32-bit UEFI tablets (some Windows 8.1 tablets)
- Intel Atom-based devices with 32-bit UEFI
- Some older UEFI systems
- Modern systems may require CSM/Legacy mode disabled and UEFI mode enabled

## Using ASCII-OS

### Main Menu

When ASCII-OS boots, you'll see:
- **Top Bar**: Clock and menu items "ASCII-OS • Activities • Files • Apps"
- **Main Menu**: Application launcher
- **Dock**: Hotkey reference at bottom

### Navigation

- **Arrow Keys**: Move the cursor crosshair overlay
- **Letter Keys**: Launch applications (N/C/E/D/Q)

### Applications

#### Notepad (N)
- Multi-line text editor
- Type freely with Enter for new lines
- **F2**: Save to `\notepad.txt` (if filesystem available)
- **ESC**: Return to main menu

#### Calculator (C)
- Enter arithmetic expressions
- Supports: `+`, `-`, `*`, `/`
- Example: `5+3*2` evaluates to `11`
- **Enter**: Calculate result
- **ESC**: Return to main menu

#### Editor (E)
- Edits `\sample.txt`
- **F3**: Reload file from disk
- **F2**: Save changes
- **ESC**: Return to main menu

#### Donut (D)
- Rotating ASCII art donut animation
- Classic demo effect
- **ESC**: Return to main menu

### File System Notes

- ASCII-OS attempts to use UEFI's Simple File System Protocol
- Files are saved to the EFI System Partition (ESP)
- If no writable filesystem is available, applications work in-memory only
- Typical ESP is FAT32 formatted and mounted at `/` from UEFI perspective

## Architecture & Design

### Code Structure

```
src/main.c          - Single source file (~700 lines)
├─ UEFI Setup       - Initialize system table, boot services
├─ UI Functions     - draw_topbar(), draw_window(), draw_dock()
├─ Input Handling   - read_key() with UEFI ConIn protocol
├─ File I/O         - save_to_file(), load_from_file() using Simple File System
├─ Applications     - app_notepad(), app_calc(), app_editor(), app_donut()
└─ Main Loop        - Menu selection and application dispatch
```

### UEFI Protocols Used

1. **Simple Text Input** (`EFI_SIMPLE_TEXT_INPUT_PROTOCOL`)
   - Keyboard input via `ReadKeyStroke()`
   - Event-based waiting with `WaitForKey`

2. **Simple Text Output** (`EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL`)
   - Console output via `OutputString()`
   - Cursor positioning with `SetCursorPosition()`
   - Text attributes and colors

3. **Simple File System** (`EFI_SIMPLE_FILE_SYSTEM_PROTOCOL`)
   - Optional - gracefully handles absence
   - File creation, reading, and writing
   - Access to EFI System Partition

4. **Runtime Services**
   - `GetTime()` for clock display

### Memory Management

- Uses UEFI `AllocatePool()` for dynamic allocation
- Fixed-size buffers for text editing (conservative memory usage)
- Minimal memory footprint (<1MB typical)

### Limitations

1. **Not a Real OS**: This is a UEFI application, not a kernel
   - No process management or multitasking
   - No drivers (relies on UEFI firmware)
   - No memory protection beyond UEFI's own

2. **Text-Only Interface**: No framebuffer pixel graphics
   - Uses UEFI text console (typically 80x25)
   - Box-drawing characters for UI elements

3. **Limited File System**: 
   - Only accesses UEFI-visible filesystems (typically ESP)
   - Cannot mount arbitrary partitions
   - File I/O depends on firmware implementation

4. **No Mouse Support**: Keyboard only
   - Could be added via `EFI_SIMPLE_POINTER_PROTOCOL`
   - Current version focuses on keyboard input

## Acceptance Testing

### Automated Build Test

```bash
# Build should complete without errors
make clean
make
test -f out/BOOTIA32.EFI && echo "Build: PASS" || echo "Build: FAIL"
```

### QEMU Boot Test (10 second timeout)

```bash
# Boot and verify it reaches menu within 10s
timeout 10s ./examples/run_qemu_uefi32.sh out/ascii-os.iso || true
```

Expected behavior:
- Boots within 10 seconds
- Displays top bar with "ASCII-OS • Activities • Files • Apps"
- Shows main menu with application options
- Responds to keyboard input

### Manual Acceptance Tests

1. **Main Menu Display**
   - ✓ Top bar shows clock
   - ✓ Menu shows N/C/E/D/Q options
   - ✓ Dock shows hotkey reference

2. **Notepad**
   - ✓ Press N to enter
   - ✓ Type text, press Enter for new lines
   - ✓ Press F2 (shows save message)
   - ✓ Press ESC to return

3. **Calculator**
   - ✓ Press C to enter
   - ✓ Type `5+3*2`, press Enter
   - ✓ Shows result: 11
   - ✓ Press ESC to return

4. **Editor**
   - ✓ Press E to enter
   - ✓ Edit text
   - ✓ Press F2 to save
   - ✓ Press ESC to return

5. **Donut**
   - ✓ Press D to enter
   - ✓ Animation displays
   - ✓ Press ESC to return

6. **Cursor**
   - ✓ Arrow keys move cursor crosshair
   - ✓ Cursor visible on screen

## Safety Features

### Build Safety
- Build scripts never write to host block devices
- All output goes to `out/` directory within repository
- ISO creation only writes to specified output file

### Runtime Safety
- Disables UEFI watchdog timer
- Graceful handling of missing protocols
- Falls back to in-memory operation if filesystem unavailable

## Advanced Topics

### Customizing the Application

Edit `src/main.c` to add features:

1. **Add New Application**: 
   - Create `app_yourname()` function
   - Add menu option in main loop
   - Follow existing app patterns

2. **Change Colors**:
   - Modify `COLOR_*` definitions
   - Use UEFI color attributes

3. **Adjust Screen Layout**:
   - Change `SCREEN_WIDTH` and `SCREEN_HEIGHT` (less common on UEFI)
   - Modify window positions in `draw_window()` calls

### Debugging

1. **Serial Console**: QEMU shows serial output with `-serial stdio`
2. **UEFI Shell**: Boot to UEFI shell, run `fs0:\EFI\BOOT\BOOTIA32.EFI`
3. **Print Debugging**: Use `Print(L"Debug: %d\n", value);` from efilib.h

### Building with Different Toolchains

The Makefile uses GCC by default. For Clang:

```makefile
CC = clang
# Add -target i686-unknown-windows flags
```

## Contributing

This is a demonstration project showing UEFI application development. Feel free to:
- Fork and modify for your own projects
- Add new applications or features
- Improve the UI or add graphics modes
- Port to 64-bit UEFI (change ia32 to x64)

## License

See LICENSE file for details.

## Resources

- [UEFI Specification](https://uefi.org/specifications)
- [GNU-EFI Library](https://sourceforge.net/projects/gnu-efi/)
- [UEFI Programming - First Steps](https://dvdhrm.github.io/2020/01/28/uefi-programming/)
- [OSDev Wiki - UEFI](https://wiki.osdev.org/UEFI)

## Credits

Inspired by:
- TempleOS by Terry A. Davis - for the ASCII-first philosophy
- Classic UEFI demos and tutorials
- The donut.c rotating donut by Andy Sloane

---

**ASCII-OS** - Because sometimes text is all you need.
