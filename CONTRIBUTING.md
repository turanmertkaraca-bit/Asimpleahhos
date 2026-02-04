# Contributing to ASCII-OS

Thank you for your interest in contributing to ASCII-OS! This document provides guidelines for contributing to the project.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/yourusername/uefi-ascii-os.git`
3. Create a branch: `git checkout -b feature/your-feature-name`
4. Make your changes
5. Test thoroughly
6. Submit a pull request

## Development Setup

Follow the instructions in README.md to set up your development environment:

```bash
sudo apt install build-essential gnu-efi gcc-multilib xorriso qemu-system-x86 ovmf
make
```

## Code Style

### C Code Guidelines

- **Indentation**: 4 spaces (no tabs)
- **Naming**: 
  - Functions: `snake_case` (e.g., `draw_window`, `read_key`)
  - Constants: `UPPER_CASE` (e.g., `SCREEN_WIDTH`, `MAX_LINES`)
  - Types: `PascalCase` for structs (e.g., `Cursor`)
- **Comments**: 
  - Use `/* */` for block comments
  - Use `//` for single-line comments
  - Document UEFI protocol usage
  - Explain non-obvious algorithms

### Example

```c
/* Draw a window frame using box drawing characters */
VOID draw_window(UINTN x, UINTN y, UINTN width, UINTN height, CHAR16 *title) {
    ConOut->SetAttribute(ConOut, COLOR_WINDOW);
    
    // Top border with rounded corners
    set_cursor(x, y);
    ConOut->OutputString(ConOut, L"\u256d");
    
    // ... rest of implementation
}
```

## Adding New Applications

To add a new built-in application:

1. Create the app function in `src/main.c`:

```c
VOID app_yourname(VOID) {
    EFI_INPUT_KEY key;
    BOOLEAN running = TRUE;
    
    clear_screen();
    draw_topbar();
    draw_window(10, 3, 60, 18, L" Your App ");
    
    while (running) {
        // Your app logic
        key = read_key();
        
        if (key.ScanCode == SCAN_ESC) {
            running = FALSE;
        }
        // Handle other keys
    }
}
```

2. Add menu entry in `efi_main()`:

```c
set_cursor(27, 15);
ConOut->OutputString(ConOut, L"[Y] Your App");

// In key handling:
else if (key.UnicodeChar == L'y' || key.UnicodeChar == L'Y') {
    app_yourname();
}
```

3. Update dock in `draw_dock()`:

```c
ConOut->OutputString(ConOut, L"[N]otepad  [C]alc  [E]ditor  [D]onut  [Y]ourApp  [Q]uit");
```

## Testing

### Before Submitting

1. **Build Test**: Ensure clean build
   ```bash
   make clean
   make
   ```

2. **ISO Test**: Verify ISO creation
   ```bash
   ./tools/make_iso_uefi32.sh out/BOOTIA32.EFI out/ascii-os.iso
   ```

3. **QEMU Test**: Boot and test functionality
   ```bash
   ./examples/run_qemu_uefi32.sh out/ascii-os.iso
   ```

4. **Manual Testing**: Test all affected features
   - Navigate through menus
   - Test keyboard input
   - Verify file operations (if applicable)
   - Check error handling

### Test Checklist

- [ ] Code compiles without warnings
- [ ] Application boots in QEMU
- [ ] All existing apps still work
- [ ] New features work as documented
- [ ] ESC key returns to menu
- [ ] No memory leaks (use minimal allocations)
- [ ] Graceful handling of missing protocols

## Documentation

Update documentation when you:
- Add new features
- Change behavior
- Add new dependencies
- Modify build process

Files to update:
- `README.md` - User-facing documentation
- `CONTRIBUTING.md` - This file
- Code comments - Inline documentation

## Pull Request Process

1. **Title**: Clear, descriptive title
   - Good: "Add snake game application"
   - Bad: "Update code"

2. **Description**: Explain what and why
   ```
   ## Changes
   - Added Snake game as new app
   - Added arrow key handling for game
   - Updated menu to include Snake option
   
   ## Testing
   - Tested in QEMU
   - Verified all directions work
   - Tested collision detection
   ```

3. **Small PRs**: Prefer smaller, focused PRs over large ones

4. **One Feature Per PR**: Each PR should address one feature/fix

## Common Issues

### Build Errors

**"GNU-EFI not found"**
```bash
sudo apt install gnu-efi
```

**"32-bit compilation failed"**
```bash
sudo apt install gcc-multilib
```

### Runtime Issues

**Application crashes**
- Check for null pointer dereferences
- Verify UEFI protocol availability
- Test error handling paths

**File operations fail**
- Remember filesystem is optional
- Always check return status
- Provide in-memory fallback

## UEFI Development Tips

1. **Protocol Availability**: Always check if protocols exist
   ```c
   status = BS->LocateProtocol(&guid, NULL, (VOID **)&protocol);
   if (EFI_ERROR(status)) {
       // Handle gracefully
   }
   ```

2. **Memory**: Use `AllocatePool` and `FreePool`
   ```c
   CHAR16 *buffer;
   BS->AllocatePool(EfiLoaderData, size, (VOID **)&buffer);
   // ... use buffer ...
   BS->FreePool(buffer);
   ```

3. **Unicode**: UEFI uses UTF-16 (CHAR16)
   ```c
   CHAR16 *str = L"Unicode string";
   ```

4. **Error Handling**: Check EFI_STATUS
   ```c
   if (EFI_ERROR(status)) {
       // Handle error
       return status;
   }
   ```

## Resources

- [UEFI Specification](https://uefi.org/specifications)
- [GNU-EFI Documentation](https://sourceforge.net/projects/gnu-efi/)
- [OSDev UEFI Wiki](https://wiki.osdev.org/UEFI)

## Questions?

- Open an issue for bugs or feature requests
- Start a discussion for general questions
- Check existing issues before creating new ones

## Code of Conduct

- Be respectful and constructive
- Welcome newcomers
- Focus on the code, not the person
- Assume good intentions

Thank you for contributing to ASCII-OS!
