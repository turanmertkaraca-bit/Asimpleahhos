/*
 * ASCII-OS: A TempleOS-inspired 32-bit UEFI Application
 * 
 * This is a single-file UEFI application that provides a text-based
 * operating system environment using only UEFI boot services.
 */

#include <efi.h>
#include <efilib.h>

/* Global UEFI system table and boot services */
EFI_SYSTEM_TABLE *ST;
EFI_BOOT_SERVICES *BS;
EFI_SIMPLE_TEXT_INPUT_PROTOCOL *ConIn;
EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL *ConOut;

/* Screen dimensions (typical UEFI console) */
#define SCREEN_WIDTH 80
#define SCREEN_HEIGHT 25

/* Color attributes for text */
#define COLOR_NORMAL    EFI_TEXT_ATTR(EFI_LIGHTGRAY, EFI_BLACK)
#define COLOR_TOPBAR    EFI_TEXT_ATTR(EFI_BLACK, EFI_LIGHTGRAY)
#define COLOR_HIGHLIGHT EFI_TEXT_ATTR(EFI_YELLOW, EFI_BLACK)
#define COLOR_WINDOW    EFI_TEXT_ATTR(EFI_WHITE, EFI_BLUE)

/* Cursor position for overlay */
typedef struct {
    UINTN x;
    UINTN y;
} Cursor;

Cursor cursor = {40, 12};

/* Buffer for notepad and editor */
#define MAX_LINES 100
#define MAX_LINE_LENGTH 256
CHAR16 notepad_buffer[MAX_LINES][MAX_LINE_LENGTH];
UINTN notepad_lines = 0;
UINTN notepad_cursor_line = 0;
UINTN notepad_cursor_col = 0;

/* Simple math expression evaluator */
INTN evaluate_expression(CHAR16 *expr) {
    INTN result = 0;
    INTN current_num = 0;
    CHAR16 op = L'+';
    UINTN i = 0;
    
    while (expr[i] != 0) {
        if (expr[i] >= L'0' && expr[i] <= L'9') {
            current_num = current_num * 10 + (expr[i] - L'0');
        } else if (expr[i] == L'+' || expr[i] == L'-' || 
                   expr[i] == L'*' || expr[i] == L'/') {
            /* Apply previous operation */
            if (op == L'+') result += current_num;
            else if (op == L'-') result -= current_num;
            else if (op == L'*') result *= current_num;
            else if (op == L'/' && current_num != 0) result /= current_num;
            
            op = expr[i];
            current_num = 0;
        }
        i++;
    }
    
    /* Apply final operation */
    if (op == L'+') result += current_num;
    else if (op == L'-') result -= current_num;
    else if (op == L'*') result *= current_num;
    else if (op == L'/' && current_num != 0) result /= current_num;
    
    return result;
}

/* Clear screen and reset attributes */
VOID clear_screen(VOID) {
    ConOut->ClearScreen(ConOut);
    ConOut->SetAttribute(ConOut, COLOR_NORMAL);
}

/* Set cursor position */
VOID set_cursor(UINTN x, UINTN y) {
    ConOut->SetCursorPosition(ConOut, x, y);
}

/* Draw top bar with clock and menu */
VOID draw_topbar(VOID) {
    EFI_TIME time;
    CHAR16 buf[100];
    
    /* Get current time from UEFI runtime services */
    ST->RuntimeServices->GetTime(&time, NULL);
    
    ConOut->SetAttribute(ConOut, COLOR_TOPBAR);
    set_cursor(0, 0);
    
    /* Clear the line */
    for (UINTN i = 0; i < SCREEN_WIDTH; i++) {
        ConOut->OutputString(ConOut, L" ");
    }
    
    /* Draw menu items */
    set_cursor(1, 0);
    SPrint(buf, sizeof(buf), L"ASCII-OS  \u2022  Activities  \u2022  Files  \u2022  Apps");
    ConOut->OutputString(ConOut, buf);
    
    /* Draw clock on right side */
    set_cursor(60, 0);
    SPrint(buf, sizeof(buf), L"%02d:%02d:%02d", time.Hour, time.Minute, time.Second);
    ConOut->OutputString(ConOut, buf);
    
    ConOut->SetAttribute(ConOut, COLOR_NORMAL);
}

/* Draw dock/menu with hotkeys */
VOID draw_dock(VOID) {
    set_cursor(2, 23);
    ConOut->SetAttribute(ConOut, COLOR_HIGHLIGHT);
    ConOut->OutputString(ConOut, L"[N]otepad  [C]alc  [E]ditor  [D]onut  [Q]uit");
    ConOut->SetAttribute(ConOut, COLOR_NORMAL);
}

/* Draw a window frame using box drawing characters */
VOID draw_window(UINTN x, UINTN y, UINTN width, UINTN height, CHAR16 *title) {
    ConOut->SetAttribute(ConOut, COLOR_WINDOW);
    
    /* Top border */
    set_cursor(x, y);
    ConOut->OutputString(ConOut, L"\u256d");  /* Rounded top-left */
    for (UINTN i = 0; i < width - 2; i++) {
        ConOut->OutputString(ConOut, L"\u2500");  /* Horizontal line */
    }
    ConOut->OutputString(ConOut, L"\u256e");  /* Rounded top-right */
    
    /* Title */
    if (title) {
        UINTN title_len = StrLen(title);
        set_cursor(x + (width - title_len) / 2, y);
        ConOut->OutputString(ConOut, title);
    }
    
    /* Sides */
    for (UINTN i = 1; i < height - 1; i++) {
        set_cursor(x, y + i);
        ConOut->OutputString(ConOut, L"\u2502");  /* Vertical line */
        set_cursor(x + width - 1, y + i);
        ConOut->OutputString(ConOut, L"\u2502");
    }
    
    /* Bottom border */
    set_cursor(x, y + height - 1);
    ConOut->OutputString(ConOut, L"\u2570");  /* Rounded bottom-left */
    for (UINTN i = 0; i < width - 2; i++) {
        ConOut->OutputString(ConOut, L"\u2500");
    }
    ConOut->OutputString(ConOut, L"\u256f");  /* Rounded bottom-right */
    
    ConOut->SetAttribute(ConOut, COLOR_NORMAL);
}

/* Read a single keystroke with waiting */
EFI_INPUT_KEY read_key(VOID) {
    EFI_INPUT_KEY key;
    UINTN index;
    
    /* Wait for key event */
    BS->WaitForEvent(1, &ConIn->WaitForKey, &index);
    
    /* Read the keystroke */
    ConIn->ReadKeyStroke(ConIn, &key);
    
    return key;
}

/* Save buffer to file using UEFI Simple File System Protocol */
EFI_STATUS save_to_file(CHAR16 *filename, CHAR16 buffer[MAX_LINES][MAX_LINE_LENGTH], UINTN num_lines) {
    EFI_STATUS status;
    EFI_GUID fs_guid = EFI_SIMPLE_FILE_SYSTEM_PROTOCOL_GUID;
    EFI_SIMPLE_FILE_SYSTEM_PROTOCOL *fs;
    EFI_FILE_PROTOCOL *root;
    EFI_FILE_PROTOCOL *file;
    UINTN handles_count = 0;
    EFI_HANDLE *handles = NULL;
    
    /* Locate filesystem protocol - try to find writable filesystem */
    status = BS->LocateHandleBuffer(ByProtocol, &fs_guid, NULL, &handles_count, &handles);
    if (EFI_ERROR(status) || handles_count == 0) {
        /* No filesystem available */
        return EFI_NOT_FOUND;
    }
    
    /* Open the first available filesystem */
    status = BS->HandleProtocol(handles[0], &fs_guid, (VOID **)&fs);
    BS->FreePool(handles);
    
    if (EFI_ERROR(status)) {
        return status;
    }
    
    /* Open the root directory */
    status = fs->OpenVolume(fs, &root);
    if (EFI_ERROR(status)) {
        return status;
    }
    
    /* Create/open the file for writing */
    status = root->Open(root, &file, filename, 
                       EFI_FILE_MODE_READ | EFI_FILE_MODE_WRITE | EFI_FILE_MODE_CREATE,
                       0);
    
    if (EFI_ERROR(status)) {
        root->Close(root);
        return status;
    }
    
    /* Write each line to the file */
    for (UINTN i = 0; i < num_lines; i++) {
        UINTN len = StrLen(buffer[i]) * sizeof(CHAR16);
        file->Write(file, &len, buffer[i]);
        
        /* Add newline */
        CHAR16 newline[] = L"\r\n";
        len = 4;
        file->Write(file, &len, newline);
    }
    
    file->Close(file);
    root->Close(root);
    
    return EFI_SUCCESS;
}

/* Load file from UEFI filesystem */
EFI_STATUS load_from_file(CHAR16 *filename, CHAR16 buffer[MAX_LINES][MAX_LINE_LENGTH], UINTN *num_lines) {
    EFI_STATUS status;
    EFI_GUID fs_guid = EFI_SIMPLE_FILE_SYSTEM_PROTOCOL_GUID;
    EFI_SIMPLE_FILE_SYSTEM_PROTOCOL *fs;
    EFI_FILE_PROTOCOL *root;
    EFI_FILE_PROTOCOL *file;
    UINTN handles_count = 0;
    EFI_HANDLE *handles = NULL;
    CHAR16 *file_buffer;
    UINTN file_size = 8192;  /* Read up to 8KB */
    
    *num_lines = 0;
    
    /* Locate filesystem protocol */
    status = BS->LocateHandleBuffer(ByProtocol, &fs_guid, NULL, &handles_count, &handles);
    if (EFI_ERROR(status) || handles_count == 0) {
        return EFI_NOT_FOUND;
    }
    
    status = BS->HandleProtocol(handles[0], &fs_guid, (VOID **)&fs);
    BS->FreePool(handles);
    
    if (EFI_ERROR(status)) return status;
    
    status = fs->OpenVolume(fs, &root);
    if (EFI_ERROR(status)) return status;
    
    /* Open file for reading */
    status = root->Open(root, &file, filename, EFI_FILE_MODE_READ, 0);
    if (EFI_ERROR(status)) {
        root->Close(root);
        return status;
    }
    
    /* Allocate buffer for file contents */
    status = BS->AllocatePool(EfiLoaderData, file_size, (VOID **)&file_buffer);
    if (EFI_ERROR(status)) {
        file->Close(file);
        root->Close(root);
        return status;
    }
    
    /* Read file */
    status = file->Read(file, &file_size, file_buffer);
    file->Close(file);
    root->Close(root);
    
    if (EFI_ERROR(status)) {
        BS->FreePool(file_buffer);
        return status;
    }
    
    /* Parse into lines */
    UINTN line = 0;
    UINTN col = 0;
    for (UINTN i = 0; i < file_size / sizeof(CHAR16) && line < MAX_LINES; i++) {
        if (file_buffer[i] == L'\r' || file_buffer[i] == L'\n') {
            buffer[line][col] = 0;
            if (col > 0) line++;
            col = 0;
        } else if (col < MAX_LINE_LENGTH - 1) {
            buffer[line][col++] = file_buffer[i];
        }
    }
    
    if (col > 0) {
        buffer[line][col] = 0;
        line++;
    }
    
    *num_lines = line;
    BS->FreePool(file_buffer);
    
    return EFI_SUCCESS;
}

/* Notepad application */
VOID app_notepad(VOID) {
    EFI_INPUT_KEY key;
    BOOLEAN running = TRUE;
    
    clear_screen();
    draw_topbar();
    draw_window(10, 3, 60, 18, L" Notepad ");
    
    set_cursor(12, 20);
    ConOut->OutputString(ConOut, L"Type text. F2=Save, ESC=Exit");
    
    notepad_cursor_line = 0;
    notepad_cursor_col = 0;
    
    while (running) {
        /* Display current buffer */
        for (UINTN i = 0; i < 16 && i < notepad_lines; i++) {
            set_cursor(12, 4 + i);
            ConOut->OutputString(ConOut, L"                                                      ");
            set_cursor(12, 4 + i);
            ConOut->OutputString(ConOut, notepad_buffer[i]);
        }
        
        /* Show cursor */
        set_cursor(12 + notepad_cursor_col, 4 + notepad_cursor_line);
        
        key = read_key();
        
        if (key.ScanCode == SCAN_ESC) {
            running = FALSE;
        } else if (key.ScanCode == SCAN_F2) {
            /* Save to file */
            EFI_STATUS status = save_to_file(L"\\notepad.txt", notepad_buffer, notepad_lines);
            set_cursor(12, 20);
            if (EFI_ERROR(status)) {
                ConOut->OutputString(ConOut, L"Save failed (filesystem unavailable)");
            } else {
                ConOut->OutputString(ConOut, L"Saved to \\notepad.txt            ");
            }
        } else if (key.UnicodeChar == CHAR_BACKSPACE) {
            if (notepad_cursor_col > 0) {
                notepad_cursor_col--;
                notepad_buffer[notepad_cursor_line][notepad_cursor_col] = 0;
            }
        } else if (key.UnicodeChar == CHAR_CARRIAGE_RETURN) {
            notepad_buffer[notepad_cursor_line][notepad_cursor_col] = 0;
            notepad_cursor_line++;
            notepad_cursor_col = 0;
            if (notepad_cursor_line >= MAX_LINES) notepad_cursor_line = MAX_LINES - 1;
            if (notepad_cursor_line >= notepad_lines) notepad_lines = notepad_cursor_line + 1;
        } else if (key.UnicodeChar >= 32 && key.UnicodeChar < 127) {
            if (notepad_cursor_col < MAX_LINE_LENGTH - 1) {
                notepad_buffer[notepad_cursor_line][notepad_cursor_col++] = key.UnicodeChar;
                notepad_buffer[notepad_cursor_line][notepad_cursor_col] = 0;
                if (notepad_cursor_line >= notepad_lines) notepad_lines = notepad_cursor_line + 1;
            }
        }
    }
}

/* Calculator application */
VOID app_calc(VOID) {
    EFI_INPUT_KEY key;
    BOOLEAN running = TRUE;
    CHAR16 input[128];
    UINTN input_pos = 0;
    CHAR16 result_str[64];
    
    input[0] = 0;
    
    clear_screen();
    draw_topbar();
    draw_window(15, 6, 50, 12, L" Calculator ");
    
    set_cursor(17, 8);
    ConOut->OutputString(ConOut, L"Enter expression (e.g., 5+3*2):");
    
    set_cursor(17, 15);
    ConOut->OutputString(ConOut, L"ENTER=Calculate, ESC=Exit");
    
    while (running) {
        /* Display input */
        set_cursor(17, 10);
        ConOut->OutputString(ConOut, L"                                              ");
        set_cursor(17, 10);
        ConOut->OutputString(ConOut, input);
        
        key = read_key();
        
        if (key.ScanCode == SCAN_ESC) {
            running = FALSE;
        } else if (key.UnicodeChar == CHAR_CARRIAGE_RETURN) {
            /* Evaluate expression */
            INTN result = evaluate_expression(input);
            SPrint(result_str, sizeof(result_str), L"Result: %d", result);
            
            set_cursor(17, 12);
            ConOut->OutputString(ConOut, L"                                              ");
            set_cursor(17, 12);
            ConOut->OutputString(ConOut, result_str);
            
            /* Clear input */
            input[0] = 0;
            input_pos = 0;
        } else if (key.UnicodeChar == CHAR_BACKSPACE) {
            if (input_pos > 0) {
                input_pos--;
                input[input_pos] = 0;
            }
        } else if ((key.UnicodeChar >= L'0' && key.UnicodeChar <= L'9') ||
                   key.UnicodeChar == L'+' || key.UnicodeChar == L'-' ||
                   key.UnicodeChar == L'*' || key.UnicodeChar == L'/') {
            if (input_pos < 127) {
                input[input_pos++] = key.UnicodeChar;
                input[input_pos] = 0;
            }
        }
    }
}

/* Editor application */
VOID app_editor(VOID) {
    EFI_INPUT_KEY key;
    BOOLEAN running = TRUE;
    CHAR16 editor_buffer[MAX_LINES][MAX_LINE_LENGTH];
    UINTN editor_lines = 1;
    UINTN editor_cursor_line = 0;
    UINTN editor_cursor_col = 0;
    
    /* Try to load sample.txt */
    EFI_STATUS status = load_from_file(L"\\sample.txt", editor_buffer, &editor_lines);
    
    if (EFI_ERROR(status)) {
        /* Create default content */
        StrCpy(editor_buffer[0], L"This is a sample file.");
        StrCpy(editor_buffer[1], L"Edit this text and press F2 to save.");
        editor_lines = 2;
    }
    
    clear_screen();
    draw_topbar();
    draw_window(8, 2, 64, 20, L" Editor - sample.txt ");
    
    set_cursor(10, 21);
    ConOut->OutputString(ConOut, L"F2=Save, F3=Reload, ESC=Exit");
    
    while (running) {
        /* Display buffer */
        for (UINTN i = 0; i < 18 && i < editor_lines; i++) {
            set_cursor(10, 3 + i);
            ConOut->OutputString(ConOut, L"                                                            ");
            set_cursor(10, 3 + i);
            ConOut->OutputString(ConOut, editor_buffer[i]);
        }
        
        /* Show cursor */
        set_cursor(10 + editor_cursor_col, 3 + editor_cursor_line);
        
        key = read_key();
        
        if (key.ScanCode == SCAN_ESC) {
            running = FALSE;
        } else if (key.ScanCode == SCAN_F2) {
            /* Save file */
            status = save_to_file(L"\\sample.txt", editor_buffer, editor_lines);
            set_cursor(10, 21);
            if (EFI_ERROR(status)) {
                ConOut->OutputString(ConOut, L"Save failed (filesystem unavailable)");
            } else {
                ConOut->OutputString(ConOut, L"Saved to \\sample.txt            ");
            }
        } else if (key.ScanCode == SCAN_F3) {
            /* Reload file */
            load_from_file(L"\\sample.txt", editor_buffer, &editor_lines);
            editor_cursor_line = 0;
            editor_cursor_col = 0;
        } else if (key.UnicodeChar == CHAR_BACKSPACE) {
            if (editor_cursor_col > 0) {
                editor_cursor_col--;
                editor_buffer[editor_cursor_line][editor_cursor_col] = 0;
            }
        } else if (key.UnicodeChar == CHAR_CARRIAGE_RETURN) {
            editor_buffer[editor_cursor_line][editor_cursor_col] = 0;
            editor_cursor_line++;
            editor_cursor_col = 0;
            if (editor_cursor_line >= MAX_LINES) editor_cursor_line = MAX_LINES - 1;
            if (editor_cursor_line >= editor_lines) editor_lines = editor_cursor_line + 1;
        } else if (key.UnicodeChar >= 32 && key.UnicodeChar < 127) {
            if (editor_cursor_col < MAX_LINE_LENGTH - 1) {
                editor_buffer[editor_cursor_line][editor_cursor_col++] = key.UnicodeChar;
                editor_buffer[editor_cursor_line][editor_cursor_col] = 0;
                if (editor_cursor_line >= editor_lines) editor_lines = editor_cursor_line + 1;
            }
        }
    }
}

/* Rotating ASCII donut animation */
VOID app_donut(VOID) {
    EFI_INPUT_KEY key;
    CHAR16 output[1760];
    float A = 0, B = 0;
    float z[1760];
    UINTN event_index;
    
    clear_screen();
    draw_topbar();
    draw_window(5, 2, 70, 21, L" Donut Animation ");
    
    set_cursor(7, 22);
    ConOut->OutputString(ConOut, L"Press ESC to exit");
    
    while (TRUE) {
        /* Check for ESC key without blocking */
        EFI_STATUS status = BS->CheckEvent(ConIn->WaitForKey);
        if (!EFI_ERROR(status)) {
            ConIn->ReadKeyStroke(ConIn, &key);
            if (key.ScanCode == SCAN_ESC) {
                break;
            }
        }
        
        /* Clear buffers */
        for (UINTN i = 0; i < 1760; i++) {
            output[i] = L' ';
            z[i] = 0;
        }
        
        /* Render donut */
        for (float j = 0; j < 6.28f; j += 0.07f) {
            for (float i = 0; i < 6.28f; i += 0.02f) {
                float c = ((float)((int)(1000 * (float)((int)(1000 * (float)((int)(1000.0f * 3.14159265f / 180.0f * 57.29578f)))))) / 1000.0f / 1000.0f / 1000.0f;
                float d = ((float)((int)(1000 * (float)((int)(1000 * (float)((int)(1000.0f * 3.14159265f / 180.0f * 57.29578f)))))) / 1000.0f / 1000.0f / 1000.0f;
                float e = ((float)((int)(1000 * (float)((int)(1000 * (float)((int)(1000.0f * 3.14159265f / 180.0f * 57.29578f)))))) / 1000.0f / 1000.0f / 1000.0f;
                float f = ((float)((int)(1000 * (float)((int)(1000 * (float)((int)(1000.0f * 3.14159265f / 180.0f * 57.29578f)))))) / 1000.0f / 1000.0f / 1000.0f;
                float g = ((float)((int)(1000 * (float)((int)(1000 * (float)((int)(1000.0f * 3.14159265f / 180.0f * 57.29578f)))))) / 1000.0f / 1000.0f / 1000.0f;
                float h = d + 2;
                float D = 1 / (c * h * e + f * g - f * h * A);
                float l = ((float)((int)(1000 * (float)((int)(1000 * (float)((int)(1000.0f * 3.14159265f / 180.0f * 57.29578f)))))) / 1000.0f / 1000.0f / 1000.0f;
                float m = ((float)((int)(1000 * (float)((int)(1000 * (float)((int)(1000.0f * 3.14159265f / 180.0f * 57.29578f)))))) / 1000.0f / 1000.0f / 1000.0f;
                float n = ((float)((int)(1000 * (float)((int)(1000 * (float)((int)(1000.0f * 3.14159265f / 180.0f * 57.29578f)))))) / 1000.0f / 1000.0f / 1000.0f;
                int x = 40 + 30 * D * (l * h * m - n * g);
                int y = 12 + 15 * D * (l * h * A + n * e);
                int o = x + 80 * y;
                int N = 8 * ((f * e - c * d * g) * m - c * d * e - f * g - l * d * A);
                if (22 > y && y > 0 && x > 0 && 80 > x && D > z[o]) {
                    z[o] = D;
                    output[o] = L".,-~:;=!*#$@"[N > 0 ? N : 0];
                }
            }
        }
        
        /* Display donut (simplified for demo) */
        for (UINTN k = 0; k < 20; k++) {
            set_cursor(7, 3 + k);
            CHAR16 line[70];
            for (UINTN m = 0; m < 69; m++) {
                line[m] = (k * 69 + m < 1760) ? output[k * 69 + m] : L' ';
            }
            line[69] = 0;
            ConOut->OutputString(ConOut, line);
        }
        
        A += 0.04f;
        B += 0.02f;
        
        /* Small delay */
        BS->Stall(50000);  /* 50ms delay */
    }
}

/* Main UEFI entry point */
EFI_STATUS EFIAPI efi_main(EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE *SystemTable) {
    EFI_INPUT_KEY key;
    BOOLEAN running = TRUE;
    
    /* Initialize GNU-EFI library */
    InitializeLib(ImageHandle, SystemTable);
    
    /* Store global references */
    ST = SystemTable;
    BS = SystemTable->BootServices;
    ConIn = SystemTable->ConIn;
    ConOut = SystemTable->ConOut;
    
    /* Initialize notepad buffer */
    for (UINTN i = 0; i < MAX_LINES; i++) {
        notepad_buffer[i][0] = 0;
    }
    notepad_lines = 1;
    
    /* Disable watchdog timer */
    BS->SetWatchdogTimer(0, 0, 0, NULL);
    
    /* Main menu loop */
    while (running) {
        clear_screen();
        draw_topbar();
        
        /* Main menu window */
        draw_window(25, 8, 30, 10, L" Main Menu ");
        
        set_cursor(27, 10);
        ConOut->OutputString(ConOut, L"[N] Notepad");
        set_cursor(27, 11);
        ConOut->OutputString(ConOut, L"[C] Calculator");
        set_cursor(27, 12);
        ConOut->OutputString(ConOut, L"[E] Editor");
        set_cursor(27, 13);
        ConOut->OutputString(ConOut, L"[D] Donut Animation");
        set_cursor(27, 14);
        ConOut->OutputString(ConOut, L"[Q] Quit to Firmware");
        
        draw_dock();
        
        /* Draw cursor overlay */
        set_cursor(cursor.x, cursor.y);
        ConOut->OutputString(ConOut, L"+");
        
        key = read_key();
        
        /* Handle arrow keys for cursor movement */
        if (key.ScanCode == SCAN_UP && cursor.y > 1) {
            cursor.y--;
        } else if (key.ScanCode == SCAN_DOWN && cursor.y < SCREEN_HEIGHT - 2) {
            cursor.y++;
        } else if (key.ScanCode == SCAN_LEFT && cursor.x > 0) {
            cursor.x--;
        } else if (key.ScanCode == SCAN_RIGHT && cursor.x < SCREEN_WIDTH - 1) {
            cursor.x++;
        }
        /* Handle menu selections */
        else if (key.UnicodeChar == L'n' || key.UnicodeChar == L'N') {
            app_notepad();
        } else if (key.UnicodeChar == L'c' || key.UnicodeChar == L'C') {
            app_calc();
        } else if (key.UnicodeChar == L'e' || key.UnicodeChar == L'E') {
            app_editor();
        } else if (key.UnicodeChar == L'd' || key.UnicodeChar == L'D') {
            app_donut();
        } else if (key.UnicodeChar == L'q' || key.UnicodeChar == L'Q') {
            running = FALSE;
        }
    }
    
    clear_screen();
    ConOut->OutputString(ConOut, L"Goodbye from ASCII-OS!\r\n");
    
    return EFI_SUCCESS;
}
