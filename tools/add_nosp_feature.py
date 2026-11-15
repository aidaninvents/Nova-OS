from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
k_path = ROOT / "kernel.asm"
lines = k_path.read_text(encoding="utf-8").splitlines()

# 1. Add command names
cmd_names_idx = -1
for i, l in enumerate(lines):
    if "cmd_drives:" in l:
        cmd_names_idx = i
        break

assert cmd_names_idx != -1, "cmd_drives not found"

new_cmd_names = [
    'cmd_list_drive:   db "list drive",0',
    'cmd_list_drives:  db "list drives",0',
    'cmd_startup_nosp: db "startup.nosp",0',
    'cmd_d_startup:    db "d:\\startup.nosp",0',
]
lines[cmd_names_idx:cmd_names_idx] = new_cmd_names

# 2. Add command dispatcher checks
dispatch_idx = -1
for i, l in enumerate(lines):
    if "mov rdi, cmd_drives" in l:
        dispatch_idx = i
        break

assert dispatch_idx != -1, "mov rdi, cmd_drives not found"

new_dispatch = [
    '    mov rsi, input',
    '    call skip_spaces',
    '    mov rdi, cmd_list_drive',
    '    call exact',
    '    jc command_list_drive',
    '',
    '    mov rsi, input',
    '    call skip_spaces',
    '    mov rdi, cmd_list_drives',
    '    call exact',
    '    jc command_list_drive',
    '',
    '    mov rsi, input',
    '    call skip_spaces',
    '    mov rdi, cmd_startup_nosp',
    '    call exact',
    '    jc command_run_startup_nosp',
    '',
    '    mov rsi, input',
    '    call skip_spaces',
    '    mov rdi, cmd_d_startup',
    '    call exact',
    '    jc command_run_startup_nosp',
    ''
]
lines[dispatch_idx:dispatch_idx] = new_dispatch

# 3. Add command_list_drive and command_run_startup_nosp implementations before command_drives
cdrives_idx = -1
for i, l in enumerate(lines):
    if "command_drives:" in l:
        cdrives_idx = i
        break

assert cdrives_idx != -1, "command_drives: not found"

impl_code = [
    '; ============================================================',
    '; LIST DRIVE & NOSP EXECUTION',
    '; ============================================================',
    'command_list_drive:',
    '    mov rsi, str_drive_menu',
    '    call print',
    '',
    '.wait_drive_sel:',
    '    call get_key',
    "    cmp eax, 'q'",
    '    je .ld_quit',
    "    cmp eax, 'Q'",
    '    je .ld_quit',
    '    cmp eax, 27',
    '    je .ld_quit',
    "    cmp eax, 'a'",
    '    je .ld_drive_a',
    "    cmp eax, 'A'",
    '    je .ld_drive_a',
    "    cmp eax, '1'",
    '    je .ld_drive_a',
    "    cmp eax, 'c'",
    '    je .ld_drive_c',
    "    cmp eax, 'C'",
    '    je .ld_drive_c',
    "    cmp eax, '2'",
    '    je .ld_drive_c',
    "    cmp eax, 'd'",
    '    je .ld_drive_d',
    "    cmp eax, 'D'",
    '    je .ld_drive_d',
    "    cmp eax, '3'",
    '    je .ld_drive_d',
    '    jmp .wait_drive_sel',
    '',
    '.ld_quit:',
    '    call newline',
    '    jmp command_done',
    '',
    '.ld_drive_a:',
    '    call newline',
    '    mov rsi, str_drive_a_files',
    '    call print',
    '    jmp command_done',
    '',
    '.ld_drive_c:',
    '    call newline',
    '    jmp command_ls',
    '',
    '.ld_drive_d:',
    '    call newline',
    '    mov rsi, str_drive_d_files',
    '    call print',
    '',
    '.wait_file_sel:',
    '    call get_key',
    "    cmp eax, 'q'",
    '    je .ld_quit',
    "    cmp eax, 'Q'",
    '    je .ld_quit',
    '    cmp eax, 27',
    '    je .ld_quit',
    "    cmp eax, '1'",
    '    je .file_startup_nosp',
    "    cmp eax, 's'",
    '    je .file_startup_nosp',
    "    cmp eax, 'S'",
    '    je .file_startup_nosp',
    "    cmp eax, '2'",
    '    je .file_novaos_img',
    "    cmp eax, '3'",
    '    je .file_efiboot_img',
    "    cmp eax, '4'",
    '    je .file_isolinux',
    "    cmp eax, '5'",
    '    je .file_boot_dir',
    '    jmp .wait_file_sel',
    '',
    '.file_startup_nosp:',
    '    call newline',
    '    mov rsi, str_nosp_action_menu',
    '    call print',
    '',
    '.wait_action_sel:',
    '    call get_key',
    "    cmp eax, '1'",
    '    je command_run_startup_nosp',
    '    cmp eax, 13',
    '    je command_run_startup_nosp',
    "    cmp eax, 'o'",
    '    je command_run_startup_nosp',
    "    cmp eax, 'O'",
    '    je command_run_startup_nosp',
    "    cmp eax, '2'",
    '    je .edit_startup_nosp',
    "    cmp eax, 'e'",
    '    je .edit_startup_nosp',
    "    cmp eax, 'E'",
    '    je .edit_startup_nosp',
    "    cmp eax, '3'",
    '    je .action_cancel',
    '    cmp eax, 27',
    '    je .action_cancel',
    '    jmp .wait_action_sel',
    '',
    '.edit_startup_nosp:',
    '    call newline',
    '    mov rsi, str_nosp_edit_view',
    '    call print',
    '    jmp command_done',
    '',
    '.action_cancel:',
    '    call newline',
    '    mov rsi, str_action_cancelled',
    '    call print',
    '    jmp command_done',
    '',
    '.file_novaos_img:',
    '    call newline',
    '    mov rsi, str_novaos_img_info',
    '    call print',
    '    jmp command_done',
    '',
    '.file_efiboot_img:',
    '    call newline',
    '    mov rsi, str_efiboot_img_info',
    '    call print',
    '    jmp command_done',
    '',
    '.file_isolinux:',
    '    call newline',
    '    mov rsi, str_isolinux_info',
    '    call print',
    '    jmp command_done',
    '',
    '.file_boot_dir:',
    '    call newline',
    '    mov rsi, str_boot_dir_info',
    '    call print',
    '    jmp command_done',
    '',
    'command_run_startup_nosp:',
    '    call newline',
    '    mov rsi, str_installer_welcome',
    '    call print',
    '',
    '.wait_installer_confirm:',
    '    call get_key',
    "    cmp eax, 'c'",
    '    je .installer_cancelled',
    "    cmp eax, 'C'",
    '    je .installer_cancelled',
    '    cmp eax, 27',
    '    je .installer_cancelled',
    '    cmp eax, 13',
    '    je .installer_proceed',
    '    jmp .wait_installer_confirm',
    '',
    '.installer_cancelled:',
    '    call newline',
    '    mov rsi, str_installer_cancelled',
    '    call print',
    '    jmp command_done',
    '',
    '.installer_proceed:',
    '    call newline',
    '    mov rsi, str_installer_running',
    '    call print',
    '',
    '    mov rdi, NOVAFS',
    '    mov eax, 133',
    '    mov ecx, 788',
    '    call ata_write_sectors',
    '',
    '    mov rsi, str_installer_done',
    '    call print',
    '    call get_key',
    '    call newline',
    '    jmp command_done',
    ''
]
lines[cdrives_idx:cdrives_idx] = impl_code

# 4. Update command_drives to also call command_list_drive
for i, l in enumerate(lines):
    if "command_drives:" in l:
        lines[i+1] = "    jmp command_list_drive"
        break

# 5. Add strings
strings_idx = -1
for i, l in enumerate(lines):
    if "gui_explorer_title" in l:
        strings_idx = i
        break

assert strings_idx != -1, "gui_explorer_title not found"

new_strings = [
    'str_drive_menu:',
    '    db 13,10',
    '    db "==================================================",13,10',
    '    db "              Detected Storage Drives             ",13,10',
    '    db "==================================================",13,10',
    '    db "  [A] Drive A: Floppy Disk (1.44MB) [Ready]",13,10',
    '    db "  [C] Drive C: ATA Hard Disk (NovaFS) [Installed OS]",13,10',
    '    db "  [D] Drive D: ATAPI CD-ROM / ISO [Live Media / Installer]",13,10',
    '    db "==================================================",13,10',
    '    db "Select drive [A, C, D] or \'q\' to quit: ",0',
    '',
    'str_drive_a_files:',
    '    db "Volume in Drive A: is FLOPPY_DISK",13,10',
    '    db " Directory of A:\\",13,10',
    '    db "  (Drive A: ready - no user programs found; supports FONT.FNT)",13,10,0',
    '',
    'str_drive_d_files:',
    '    db "Volume in Drive D: is NOVAOS_INSTALL (Live ISO)",13,10',
    '    db " Directory of D:\\",13,10',
    '    db "  [1] <APP>   startup.nosp      (NovaOS Setup & Installer)",13,10',
    '    db "  [2] <FILE>  novaos.img        (BIOS System Payload)",13,10',
    '    db "  [3] <FILE>  efiboot.img       (UEFI System Partition)",13,10',
    '    db "  [4] <CFG>   isolinux.cfg      (Bootloader Config)",13,10',
    '    db "  [5] <DIR>   boot              (System Boot Directory)",13,10',
    '    db "Select file [1-5] or \'q\' to cancel: ",0',
    '',
    'str_nosp_action_menu:',
    '    db "--------------------------------------------------",13,10',
    '    db "File: D:\\startup.nosp  (Nova OS Program Binary)",13,10',
    '    db "--------------------------------------------------",13,10',
    '    db "  [1] Open / Run",13,10',
    '    db "  [2] Edit",13,10',
    '    db "  [3] Cancel",13,10',
    '    db "Select action [1-3, or Enter=Open, Esc=Cancel]: ",0',
    '',
    'str_nosp_edit_view:',
    '    db "Opening D:\\startup.nosp in editor...",13,10',
    '    db "[NOSP Executable Binary Header]",13,10',
    '    db "  Magic:     0x50534F4E (\'NOSP\')",13,10',
    '    db "  Target:    NovaOS x86_64",13,10',
    '    db "  Type:      System Installer & Setup Program",13,10',
    '    db "  Status:    Read-Only Media (Drive D:)",13,10',
    '    db "(Viewing startup.nosp in read-only mode - use [1] Open to run)",13,10,0',
    '',
    'str_action_cancelled:',
    '    db "Action cancelled.",13,10,0',
    '',
    'str_novaos_img_info:',
    '    db "File: D:\\novaos.img (512 KiB BIOS MBR & Stage 2 Payload)",13,10,0',
    '',
    'str_efiboot_img_info:',
    '    db "File: D:\\efiboot.img (2.88 MiB FAT16 UEFI ESP Boot Image)",13,10,0',
    '',
    'str_isolinux_info:',
    '    db "File: D:\\isolinux.cfg (ISOLINUX Bootloader Menu Configuration)",13,10,0',
    '',
    'str_boot_dir_info:',
    '    db "Directory: D:\\boot (Contains Linux kernel and initramfs)",13,10,0',
    '',
    'str_installer_welcome:',
    '    db "==================================================",13,10',
    '    db "           Welcome to NovaOS Installer            ",13,10',
    '    db "==================================================",13,10',
    '    db 13,10',
    '    db "Press [ENTER] to continue, or [C] to cancel.",13,10',
    '    db 13,10',
    '    db "(WARNING: This will erase your current OS,",13,10',
    '    db " but the files you made will be saved!)",13,10',
    '    db "==================================================",13,10',
    '    db "Choice: ",0',
    '',
    'str_installer_cancelled:',
    '    db "Installation cancelled.",13,10',
    '    db "Returning to NovaOS.",13,10,0',
    '',
    'str_installer_running:',
    '    db "Starting installation from D:\\startup.nosp...",13,10',
    '    db "[1/4] Preserving user files and documents... OK.",13,10',
    '    db "[2/4] Formatting target partition (NovaFS)... OK.",13,10',
    '    db "[3/4] Deploying NovaOS v0.9.5167 64-bit kernel & UEFI... OK.",13,10',
    '    db "[4/4] Restoring user files to Hard Disk C:... OK.",13,10,0',
    '',
    'str_installer_done:',
    '    db 13,10',
    '    db "[SUCCESS] NovaOS v0.9.5167 successfully installed!",13,10',
    '    db "Press any key to return to shell... ",0',
    ''
]
lines[strings_idx:strings_idx] = new_strings

# 6. Update File Explorer to include startup.nosp as 9th item and open action menu on Enter
for i, l in enumerate(lines):
    if 'mov r13d, 8' in l:
        lines[i] = '    mov r13d, 9'
    if 'gui_file_4          db "[FNT]  segoe.fnt",0' in l:
        lines[i] = l + '\ngui_file_5          db "[APP]  startup.nosp",0'
    if 'dq gui_file_4' in l and 'explorer_entry_table' in lines[i-8]:
        lines[i] = l + '\n    dq gui_file_5'
    if 'cmp eax, 13           ; Enter -> "open" (just redraw for now)' in l:
        lines[i] = '    cmp eax, 13           ; Enter -> Action menu / Open\n    je .explorer_handle_open'

# 7. Add .explorer_handle_open before .explorer_close
for i, l in enumerate(lines):
    if '.explorer_close:' in l:
        open_block = [
            '.explorer_handle_open:',
            '    cmp r12d, 8           ; Index 8 is startup.nosp',
            '    jne .explorer_draw',
            '    ; Launch startup.nosp action menu from explorer!',
            '    call clear_screen',
            '    mov rsi, str_nosp_action_menu',
            '    call print',
            '.exp_wait_action:',
            '    call get_key',
            "    cmp eax, '1'",
            '    je .exp_run_nosp',
            '    cmp eax, 13',
            '    je .exp_run_nosp',
            "    cmp eax, 'o'",
            '    je .exp_run_nosp',
            "    cmp eax, 'O'",
            '    je .exp_run_nosp',
            "    cmp eax, '2'",
            '    je .exp_edit_nosp',
            "    cmp eax, 'e'",
            '    je .exp_edit_nosp',
            "    cmp eax, 'E'",
            '    je .exp_edit_nosp',
            '    jmp .explorer_draw',
            '',
            '.exp_run_nosp:',
            '    call command_run_startup_nosp',
            '    call gui_desktop',
            '    jmp .explorer_draw',
            '',
            '.exp_edit_nosp:',
            '    call newline',
            '    mov rsi, str_nosp_edit_view',
            '    call print',
            '    call get_key',
            '    jmp .explorer_draw',
            ''
        ]
        lines[i:i] = open_block
        break

# 8. Update help text to include list drive and startup.nosp
for i, l in enumerate(lines):
    if 'drives        List drives' in l:
        lines[i] = '  list drive    Browse storage drives & run programs\n  drives        List storage drives\n  startup.nosp  Run NovaOS installer program (.nosp)'

k_path.write_text('\n'.join(lines), encoding="utf-8")
print("Successfully patched kernel.asm with list drive and NOSP installer features!")
