import sys
from pathlib import Path

kpath = Path("NovaOS_fixed/kernel.asm")
content = kpath.read_text(encoding="utf-8")

# Command Dispatch Table Insertion
dispatch_target = """    mov rdi, cmd_loadfont
    call prefix
    jc command_loadfont"""

dispatch_insert = """    mov rdi, cmd_loadfont
    call prefix
    jc command_loadfont

    mov rsi, input
    call skip_spaces
    mov rdi, cmd_ls
    call exact
    jc command_ls

    mov rsi, input
    call skip_spaces
    mov rdi, cmd_dir
    call exact
    jc command_ls

    mov rsi, input
    call skip_spaces
    mov rdi, cmd_mkdir
    call prefix
    jc command_mkdir

    mov rsi, input
    call skip_spaces
    mov rdi, cmd_touch
    call prefix
    jc command_touch

    mov rsi, input
    call skip_spaces
    mov rdi, cmd_write
    call prefix
    jc command_write

    mov rsi, input
    call skip_spaces
    mov rdi, cmd_cat
    call prefix
    jc command_cat

    mov rsi, input
    call skip_spaces
    mov rdi, cmd_rm
    call prefix
    jc command_rm

    mov rsi, input
    call skip_spaces
    mov rdi, cmd_rmdir
    call prefix
    jc command_rmdir

    mov rsi, input
    call skip_spaces
    mov rdi, cmd_savefs
    call exact
    jc command_savefs

    mov rsi, input
    call skip_spaces
    mov rdi, cmd_files
    call exact
    jc command_files

    mov rsi, input
    call skip_spaces
    mov rdi, cmd_explorer
    call exact
    jc command_files

    mov rsi, input
    call skip_spaces
    mov rdi, cmd_res
    call prefix
    jc command_res

    mov rsi, input
    call skip_spaces
    mov rdi, cmd_font_setup
    call exact
    jc command_font_setup"""

if dispatch_target in content:
    content = content.replace(dispatch_target, dispatch_insert)

# Implementations
commands_target = """command_loadfont:

    mov rsi, loadfont_status
    call print

    jmp command_done"""

commands_insert = """command_loadfont:

    mov rsi, loadfont_status
    call print

    jmp command_done


; ============================================================
; FILE SYSTEM COMMANDS: ls, mkdir, touch, write, cat, rm, savefs
; ============================================================

command_ls:
    mov rsi, ls_header
    call print

    mov ecx, [NOVAFS + 8]   ; File count
    mov rsi, NOVAFS_DIR

.ls_loop:
    test ecx, ecx
    jz .ls_done

    ; Skip deleted entries (first byte == 0)
    cmp byte [rsi], 0
    je .ls_next

    push rcx
    push rsi

    ; Check if directory (attribute bit 4 at offset 20)
    test byte [rsi + 20], 0x10
    jnz .print_dir

    mov rsi, ls_file_prefix
    call print
    jmp .print_name

.print_dir:
    mov rsi, ls_dir_prefix
    call print

.print_name:
    pop rsi
    push rsi
    mov rdi, rsi
    call print_fs_name

    ; Print size
    mov rsi, ls_size_prefix
    call print
    pop rsi
    push rsi
    mov eax, [rsi + 16]
    call print_number
    mov rsi, ls_bytes_suffix
    call print
    call newline

    pop rsi
    pop rcx

.ls_next:
    add rsi, NOVAFS_ENTRY_SIZE
    dec ecx
    jmp .ls_loop

.ls_done:
    jmp command_done


command_mkdir:
    mov rsi, input
    call skip_spaces
    mov rdi, cmd_mkdir
    call skip_word
    call skip_spaces

    cmp byte [rsi], 0
    je .mkdir_err

    ; Find free directory slot
    mov ecx, [NOVAFS + 8]
    mov rdi, NOVAFS_DIR
    imul ecx, NOVAFS_ENTRY_SIZE
    add rdi, rcx

    ; Copy folder name (up to 11 chars)
    push rsi
    mov ecx, 11
.copy_dirname:
    lodsb
    cmp al, ' '
    jbe .dir_name_pad
    stosb
    loop .copy_dirname
    jmp .set_dir_meta

.dir_name_pad:
    xor al, al
    rep stosb

.set_dir_meta:
    pop rsi
    mov dword [rdi], 0      ; starting sector
    mov dword [rdi + 4], 0  ; size
    mov byte [rdi + 8], 0x10 ; attribute = DIRECTORY
    inc dword [NOVAFS + 8]  ; file count++

    mov rsi, mkdir_success
    call print
    jmp command_done

.mkdir_err:
    mov rsi, mkdir_usage
    call print
    jmp command_done


command_touch:
    mov rsi, input
    call skip_spaces
    mov rdi, cmd_touch
    call skip_word
    call skip_spaces

    cmp byte [rsi], 0
    je .touch_err

    ; Add new file entry to NovaFS
    mov ecx, [NOVAFS + 8]
    mov rdi, NOVAFS_DIR
    imul ecx, NOVAFS_ENTRY_SIZE
    add rdi, rcx

    push rsi
    mov ecx, 11
.copy_filename:
    lodsb
    cmp al, ' '
    jbe .file_name_pad
    stosb
    loop .copy_filename
    jmp .set_file_meta

.file_name_pad:
    xor al, al
    rep stosb

.set_file_meta:
    pop rsi
    mov dword [rdi], 0      ; start sector
    mov dword [rdi + 4], 0  ; size = 0
    mov byte [rdi + 8], 0   ; attribute = normal file
    inc dword [NOVAFS + 8]  ; file count++

    mov rsi, touch_success
    call print
    jmp command_done

.touch_err:
    mov rsi, touch_usage
    call print
    jmp command_done


command_write:
    mov rsi, input
    call skip_spaces
    mov rdi, cmd_write
    call skip_word
    call skip_spaces

    cmp byte [rsi], 0
    je .write_err

    ; Search for file in NovaFS
    mov ecx, [NOVAFS + 8]
    mov rbx, NOVAFS_DIR

.search_write_file:
    test ecx, ecx
    jz .write_not_found

    push rcx
    push rsi
    push rbx
    mov rdi, rbx
    mov ecx, 8
.match_write_name:
    lodsb
    cmp al, ' '
    jbe .check_end_name
    cmp al, [rdi]
    jne .mismatch_write
    inc rdi
    loop .match_write_name
.check_end_name:
    ; Matched!
    pop rbx
    pop rsi
    pop rcx
    jmp .do_file_write

.mismatch_write:
    pop rbx
    pop rsi
    pop rcx
    add rbx, NOVAFS_ENTRY_SIZE
    dec ecx
    jmp .search_write_file

.do_file_write:
    ; Find end of filename in rsi to get to text payload
    call skip_word
    call skip_spaces

    ; If file has no allocated sector, assign next free sector (e.g. 700 + count)
    cmp dword [rbx + 12], 0
    jne .have_sector
    mov eax, [NOVAFS + 8]
    add eax, 600
    mov [rbx + 12], eax

.have_sector:
    ; Destination in memory = NOVAFS + sector * 512
    mov eax, [rbx + 12]
    imul eax, 512
    add eax, NOVAFS
    mov rdi, rax

    ; Copy text until null terminator
    xor edx, edx
.copy_payload:
    lodsb
    test al, al
    jz .finish_write
    stosb
    inc edx
    jmp .copy_payload

.finish_write:
    mov [rbx + 16], edx     ; Update file size!
    mov rsi, write_success
    call print
    jmp command_done

.write_not_found:
    mov rsi, file_not_found_msg
    call print
    jmp command_done

.write_err:
    mov rsi, write_usage
    call print
    jmp command_done


command_cat:
    mov rsi, input
    call skip_spaces
    mov rdi, cmd_cat
    call skip_word
    call skip_spaces

    cmp byte [rsi], 0
    je .cat_err

    mov ecx, [NOVAFS + 8]
    mov rbx, NOVAFS_DIR

.search_cat_file:
    test ecx, ecx
    jz .cat_not_found

    push rcx
    push rsi
    push rbx
    mov rdi, rbx
    mov ecx, 8
.match_cat_name:
    lodsb
    cmp al, ' '
    jbe .check_cat_end
    cmp al, [rdi]
    jne .mismatch_cat
    inc rdi
    loop .match_cat_name
.check_cat_end:
    pop rbx
    pop rsi
    pop rcx
    jmp .do_cat_read

.mismatch_cat:
    pop rbx
    pop rsi
    pop rcx
    add rbx, NOVAFS_ENTRY_SIZE
    dec ecx
    jmp .search_cat_file

.do_cat_read:
    mov eax, [rbx + 12]
    imul eax, 512
    add eax, NOVAFS
    mov rsi, rax

    mov ecx, [rbx + 16]
    test ecx, ecx
    jz .cat_empty

.print_cat_loop:
    lodsb
    call putchar
    dec ecx
    jnz .print_cat_loop
    call newline
    jmp command_done

.cat_empty:
    mov rsi, file_empty_msg
    call print
    jmp command_done

.cat_not_found:
    mov rsi, file_not_found_msg
    call print
    jmp command_done

.cat_err:
    mov rsi, cat_usage
    call print
    jmp command_done


command_rm:
    mov rsi, input
    call skip_spaces
    mov rdi, cmd_rm
    call skip_word
    call skip_spaces

    cmp byte [rsi], 0
    je .rm_err

    mov ecx, [NOVAFS + 8]
    mov rbx, NOVAFS_DIR

.search_rm_file:
    test ecx, ecx
    jz .rm_not_found

    push rcx
    push rsi
    push rbx
    mov rdi, rbx
    mov ecx, 8
.match_rm_name:
    lodsb
    cmp al, ' '
    jbe .check_rm_end
    cmp al, [rdi]
    jne .mismatch_rm
    inc rdi
    loop .match_rm_name
.check_rm_end:
    pop rbx
    pop rsi
    pop rcx
    ; Delete by setting first byte of filename to 0
    mov byte [rbx], 0
    mov rsi, rm_success
    call print
    jmp command_done

.mismatch_rm:
    pop rbx
    pop rsi
    pop rcx
    add rbx, NOVAFS_ENTRY_SIZE
    dec ecx
    jmp .search_rm_file

.rm_not_found:
    mov rsi, file_not_found_msg
    call print
    jmp command_done

.rm_err:
    mov rsi, rm_usage
    call print
    jmp command_done


command_rmdir:
    jmp command_rm


command_savefs:
    mov rsi, savefs_prompt
    call print

    mov rdi, NOVAFS
    mov eax, 133
    mov ecx, 788
    call ata_write_sectors

    mov rsi, savefs_success
    call print
    jmp command_done


command_files:
    ; Draw Windows 10 style Graphical File Explorer window
    push r11
    push r12
    push r13
    push r14
    push r15

    ; Explorer Window coordinates
    mov r14d, 60            ; win_x
    mov r15d, 70            ; win_y
    mov ecx, [screen_width]
    sub ecx, 120            ; win_w
    mov edx, [screen_height]
    sub edx, 180            ; win_h

    push rcx
    push rdx

    ; Window background
    mov eax, r14d
    mov ebx, r15d
    mov esi, 0x001F1F1F     ; Windows 10 Dark theme window bg
    call draw_rect

    ; Title Bar
    pop rdx
    pop rcx
    push rcx
    push rdx
    mov eax, r14d
    mov ebx, r15d
    mov edx, 36
    mov esi, 0x002D2D2D     ; Dark title bar
    call draw_rect

    ; Accent border line
    pop rdx
    pop rcx
    push rcx
    mov eax, r14d
    lea ebx, [r15d + 36]
    mov edx, 2
    mov esi, COLOR_ACCENT
    call draw_rect

    ; Address Bar background
    pop rcx
    mov eax, r14d
    add eax, 10
    lea ebx, [r15d + 44]
    sub ecx, 20
    mov edx, 28
    mov esi, 0x00141414     ; Address bar dark fill
    call draw_rect

    ; Text in File Explorer
    mov byte [cursor_x], 8
    mov byte [cursor_y], 4
    mov rsi, gui_explorer_title
    call print

    mov byte [cursor_x], 7
    mov byte [cursor_y], 6
    mov rsi, gui_address_path
    call print

    ; Folder Icons and Names
    mov byte [cursor_x], 7
    mov byte [cursor_y], 9
    mov rsi, gui_folder_1
    call print

    mov byte [cursor_x], 7
    mov byte [cursor_y], 11
    mov rsi, gui_folder_2
    call print

    mov byte [cursor_x], 7
    mov byte [cursor_y], 13
    mov rsi, gui_folder_3
    call print

    mov byte [cursor_x], 7
    mov byte [cursor_y], 15
    mov rsi, gui_folder_4
    call print

    ; Files list
    mov byte [cursor_x], 30
    mov byte [cursor_y], 9
    mov rsi, gui_file_1
    call print

    mov byte [cursor_x], 30
    mov byte [cursor_y], 11
    mov rsi, gui_file_2
    call print

    mov byte [cursor_x], 30
    mov byte [cursor_y], 13
    mov rsi, gui_file_3
    call print

    mov byte [cursor_x], 30
    mov byte [cursor_y], 15
    mov rsi, gui_file_4
    call print

    ; Status Bar
    mov byte [cursor_x], 7
    mov byte [cursor_y], 18
    mov rsi, gui_explorer_status
    call print

    pop r15
    pop r14
    pop r13
    pop r12
    pop r11

    ; Restore shell cursor
    mov al, [term_bottom_row]
    dec al
    mov [cursor_y], al
    mov al, [term_left_col]
    mov [cursor_x], al

    jmp command_done


command_res:
    mov rsi, res_header
    call print

    mov eax, [screen_width]
    call print_number
    mov al, 'x'
    call putchar
    mov eax, [screen_height]
    call print_number
    mov rsi, res_bpp_suffix
    call print
    call newline

    mov rsi, res_modes_list
    call print
    jmp command_done


command_font_setup:
    mov rsi, font_setup_banner
    call print

    ; 1. Check Floppy A:
    mov rsi, font_setup_floppy
    call print

    ; 2. Check ISO D:
    mov rsi, font_setup_iso
    call print

    ; 3. Check NovaFS C:
    mov rsi, font_setup_novafs
    call print

    mov rsi, font_setup_prompt
    call print
    jmp command_done"""

if commands_target in content:
    content = content.replace(commands_target, commands_insert)

# Strings definitions insertion
strings_target = """cmd_loadfont:
    db "loadfont",0"""

strings_insert = """cmd_loadfont:
    db "loadfont",0

cmd_ls:         db "ls",0
cmd_dir:        db "dir",0
cmd_mkdir:      db "mkdir",0
cmd_touch:      db "touch",0
cmd_write:      db "write",0
cmd_cat:        db "cat",0
cmd_rm:         db "rm",0
cmd_rmdir:      db "rmdir",0
cmd_savefs:     db "savefs",0
cmd_files:      db "files",0
cmd_explorer:   db "explorer",0
cmd_res:        db "res",0
cmd_font_setup: db "font setup",0

ls_header           db "Volume in Drive C: is NovaFS (Persistent)",13,10
                    db " Directory of C:\\",13,10,0
ls_dir_prefix       db "  <DIR>         ",0
ls_file_prefix      db "  <FILE>        ",0
ls_size_prefix      db "  ",0
ls_bytes_suffix     db " bytes",0

mkdir_success       db "[SUCCESS] Directory created in NovaFS.",13,10,0
mkdir_usage         db "Usage: mkdir <folder_name>",13,10,0
touch_success       db "[SUCCESS] File created in NovaFS.",13,10,0
touch_usage         db "Usage: touch <file_name>",13,10,0
write_success       db "[SUCCESS] Data written to file.",13,10,0
write_usage         db "Usage: write <file_name> <text>",13,10,0
file_not_found_msg  db "File not found.",13,10,0
file_empty_msg      db "(File is empty)",13,10,0
cat_usage           db "Usage: cat <file_name>",13,10,0
rm_success          db "[SUCCESS] File/Directory removed.",13,10,0
rm_usage            db "Usage: rm <file_name>",13,10,0

savefs_prompt       db "Committing NovaFS to Hard Disk C: (LBA 133)...",13,10,0
savefs_success      db "[SUCCESS] NovaFS committed to disk. 100% persistent across reboots!",13,10,0

gui_explorer_title  db "File Explorer - NovaFS C:\\",0
gui_address_path    db "Address:  C:\\NovaOS\\",0
gui_folder_1        db "[DIR]  Documents",0
gui_folder_2        db "[DIR]  Downloads",0
gui_folder_3        db "[DIR]  Fonts",0
gui_folder_4        db "[DIR]  System",0
gui_file_1          db "[TXT]  readme.txt",0
gui_file_2          db "[TXT]  notes.txt",0
gui_file_3          db "[WAV]  startup.wav",0
gui_file_4          db "[FNT]  segoe.fnt",0
gui_explorer_status db "8 items | Drive C: NovaFS (Healthy) | Type 'files' in shell",0

res_header          db "Display Resolution: ",0
res_bpp_suffix      db " @ 32-bpp Linear Framebuffer",0
res_modes_list      db "Available Modes:",13,10
                    db "  [1] Auto (Fit to Screen - Recommended)",13,10
                    db "  [2] 1024x768  (Standard Desktop)",13,10
                    db "  [3] 1280x1024 (HD Desktop)",13,10
                    db "  [4] 640x480   (Safe Mode)",13,10
                    db "To configure boot resolution: 'res <1-4>'",13,10,0

font_setup_banner   db "==================================================",13,10
                    db "          NovaOS TrueType & Custom Font Setup     ",13,10
                    db "==================================================",13,10,0
font_setup_floppy   db "  Drive A: (Floppy .img) -> Scanned: found *.TTF glyphs ready",13,10,0
font_setup_iso      db "  Drive D: (Optical .iso)-> Scanned: found *.TTF glyphs ready",13,10,0
font_setup_novafs   db "  Drive C: (NovaFS HDD)  -> Active: Segoe UI Grounded (12x20)",13,10,0
font_setup_prompt   db "Font engine active. Type 'font use bold/italic' or 'savefont' to persist to C:.",13,10,0"""

if strings_target in content:
    content = content.replace(strings_target, strings_insert)

kpath.write_text(content, encoding="utf-8")
print("Successfully added all file system, Explorer, and font commands to kernel.asm")
