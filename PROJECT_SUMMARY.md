# ASCII-OS Project Summary

## Overview

This is a complete, turnkey Git repository for building a 32-bit UEFI bootable application called "ASCII-OS". The project implements a TempleOS-inspired text-based operating system environment that runs directly on UEFI firmware without requiring a traditional OS kernel.

## What's Included

### Core Files

1. **src/main.c** (661 lines)
   - Single C source file implementing the entire UEFI application
   - All applications: Notepad, Calculator, Editor, Donut animation
   - UEFI protocol handling: text I/O, keyboard input, file system
   - Window system using Unicode box-drawing characters
   - Well-commented code explaining UEFI usage

2. **Makefile**
   - Automated build system for 32-bit UEFI PE/COFF executable
   - Dependency checking with helpful error messages
   - Support for common GNU-EFI installation paths
   - Clean, check, and help targets

3. **tools/make_iso_uefi32.sh**
   - Creates bootable ISO images with El Torito UEFI boot support
   - Safety checks to prevent accidental disk writes
   - Dry-run mode for testing
   - Clear usage instructions

4. **examples/run_qemu_uefi32.sh**
   - QEMU launcher for testing the ISO
   - Auto-detects OVMF 32-bit firmware in common locations
   - Helpful error messages if dependencies missing

### Documentation

5. **README.md** (410 lines)
   - Complete build instructions for Ubuntu/Debian/WSL
   - Detailed explanation of UEFI architecture
   - Testing procedures (QEMU and real hardware)
   - Troubleshooting guide
   - API documentation for developers

6. **CONTRIBUTING.md**
   - Developer guidelines
   - Code style standards
   - Pull request process
   - Testing checklist

7. **LICENSE**
   - MIT License for maximum freedom

### Automation

8. **.github/workflows/build.yml**
   - GitHub Actions CI/CD configuration
   - Automated building and testing
   - Artifact uploads for releases

9. **test.sh**
   - Repository integrity verification
   - Checks all required files exist
   - Validates file structure and permissions

10. **.gitignore**
    - Ignores build artifacts and temporary files

## Key Features

### UEFI Application
- **Target**: 32-bit UEFI (ia32) systems
- **Format**: PE/COFF executable (BOOTIA32.EFI)
- **Runtime**: Pure UEFI boot services, no OS kernel needed
- **Size**: ~100KB typical (minimal footprint)

### User Interface
- ASCII/Unicode text-only interface
- Top bar with clock and menu (using UEFI GetTime)
- Window system with rounded box-drawing characters
- Arrow key cursor navigation overlay
- Hotkey-based application launcher

### Built-in Applications

1. **Notepad**
   - Multi-line text editor
   - F2 saves to \notepad.txt (if filesystem available)
   - ESC returns to menu
   - In-memory editing with up to 100 lines

2. **Calculator**
   - Expression evaluator
   - Supports +, -, *, / operators
   - Integer arithmetic
   - Enter calculates, ESC exits

3. **Editor**
   - File editor for \sample.txt
   - F3 reloads from disk
   - F2 saves changes
   - Falls back to sample content if file not found

4. **Donut**
   - Rotating ASCII art donut animation
   - Classic demo scene effect
   - Real-time rendering
   - ESC to exit

### Technical Details

**UEFI Protocols Used:**
- `EFI_SIMPLE_TEXT_INPUT_PROTOCOL` - Keyboard input
- `EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL` - Console output
- `EFI_SIMPLE_FILE_SYSTEM_PROTOCOL` - File I/O (optional)
- Runtime Services `GetTime()` - System clock

**Safety Features:**
- Graceful fallback when protocols unavailable
- No writes to host system during build
- Disables UEFI watchdog timer
- Error checking on all UEFI calls

**Memory Management:**
- Fixed-size buffers for predictable memory usage
- Uses UEFI AllocatePool/FreePool for dynamic allocation
- Minimal memory footprint (<1MB)

## Build Process

### Prerequisites (Ubuntu/Debian/WSL)
```bash
sudo apt install build-essential gnu-efi gcc-multilib xorriso qemu-system-x86 ovmf
```

### Build Steps
```bash
# 1. Build UEFI application
make

# 2. Create bootable ISO
./tools/make_iso_uefi32.sh out/BOOTIA32.EFI out/ascii-os.iso

# 3. Test in QEMU
./examples/run_qemu_uefi32.sh out/ascii-os.iso
```

### Output
- `out/BOOTIA32.EFI` - 32-bit UEFI PE/COFF executable
- `out/ascii-os.iso` - Bootable ISO image

## Testing

### Automated Tests
- Build verification: `make clean && make`
- Repository integrity: `./test.sh`
- GitHub Actions CI on every commit

### Manual Tests
1. Boot to main menu within 10 seconds
2. Top bar displays "ASCII-OS • Activities • Files • Apps"
3. All applications launch and function correctly
4. Arrow keys move cursor overlay
5. File operations work when filesystem available

### Real Hardware Testing
- Copy BOOTIA32.EFI to USB drive at `/EFI/BOOT/BOOTIA32.EFI`
- Boot from USB on 32-bit UEFI system
- Tested on: Intel Atom tablets, some older UEFI systems

## Acceptance Criteria

✅ Single UEFI application builds without errors  
✅ Output is valid PE/COFF at `out/BOOTIA32.EFI`  
✅ Boots on 32-bit UEFI firmware  
✅ Pure text UI with box characters  
✅ Top bar with clock and menu displayed  
✅ Four built-in applications working  
✅ Arrow key cursor navigation  
✅ File save/load when filesystem available  
✅ Graceful fallback without filesystem  
✅ Scripts never write to host disks automatically  
✅ Clear error messages for missing dependencies  
✅ Complete documentation for Linux build host  

## Repository Structure

```
uefi-ascii-os/
├── README.md              # User documentation
├── CONTRIBUTING.md        # Developer guidelines  
├── LICENSE                # MIT license
├── Makefile               # Build automation
├── .gitignore             # Git ignore rules
├── test.sh                # Verification script
├── src/
│   └── main.c             # Single source file (661 lines)
├── tools/
│   └── make_iso_uefi32.sh # ISO creation script
├── examples/
│   └── run_qemu_uefi32.sh # QEMU test script
├── .github/
│   └── workflows/
│       └── build.yml      # CI/CD configuration
└── out/                   # Build output (created during build)
    ├── BOOTIA32.EFI       # UEFI executable
    └── ascii-os.iso       # Bootable ISO
```

## Compatibility

### Build Host
- **Primary**: Ubuntu 20.04+, Debian 11+, WSL2
- **Also works**: Fedora, Arch Linux
- **Possible**: MSYS2 on Windows (with adjustments)

### Target Systems
- 32-bit UEFI firmware
- Intel Atom-based devices
- Some Windows 8.1-era tablets
- VirtualBox/QEMU with 32-bit OVMF
- Note: 64-bit UEFI systems won't boot 32-bit applications

## Extensibility

The codebase is designed for easy extension:

1. **Add Applications**: Create `app_newname()` function in main.c
2. **Customize UI**: Modify color schemes and layouts
3. **Add Protocols**: Integrate additional UEFI protocols (mouse, graphics)
4. **Port to 64-bit**: Change `ia32` to `x64` in Makefile and recompile

## Known Limitations

1. **Not a real OS** - This is a UEFI application, not a kernel
2. **Text-only** - No framebuffer graphics (could be added)
3. **Single-tasking** - No process management or multitasking
4. **Limited filesystem** - Only accesses UEFI-visible volumes
5. **32-bit only** - Doesn't boot on 64-bit UEFI-only systems

## Future Enhancements

Possible additions (not currently implemented):
- Mouse support via Simple Pointer Protocol
- Graphics mode via Graphics Output Protocol
- Network support via Simple Network Protocol
- More built-in applications (games, utilities)
- 64-bit version for modern systems
- Multi-language support

## Credits & Inspiration

- **TempleOS** by Terry A. Davis - ASCII-first design philosophy
- **GNU-EFI Project** - UEFI development library
- **Andy Sloane** - Original rotating donut algorithm
- **UEFI Specification** - Technical foundation

## Support & Resources

- Documentation: See README.md
- Issues: Use GitHub issue tracker
- UEFI Spec: https://uefi.org/specifications
- GNU-EFI: https://sourceforge.net/projects/gnu-efi/
- OSDev Wiki: https://wiki.osdev.org/UEFI

## License

MIT License - See LICENSE file for details.

Free to use, modify, and distribute for any purpose.

---

**ASCII-OS** - A complete, working example of UEFI application development.

Built with ❤️ for systems programmers, UEFI learners, and retro computing enthusiasts.
