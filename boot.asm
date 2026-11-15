BITS 16
ORG 0x7C00

STAGE2_SEG     equ 0x0800
STAGE2_OFFSET  equ 0x0000
STAGE2_SECTORS equ 4

start:
    cli

    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    mov [boot_drive], dl

    mov si, boot_msg
.print:
    lodsb
    test al, al
    jz load_stage2

    mov ah, 0x0E
    int 0x10
    jmp .print


load_stage2:
    ; Load sectors 2-5 from the floppy/hard disk.
    ; These are NovaOS stage2, stored at disk LBA 1-4.

    mov ax, STAGE2_SEG
    mov es, ax
    mov bx, STAGE2_OFFSET

    mov ah, 0x02
    mov al, STAGE2_SECTORS

    mov ch, 0
    mov cl, 2
    mov dh, 0
    mov dl, [boot_drive]

    int 0x13
    jc disk_error

    ; Jump to stage2 at physical address 0x8000.
    mov dl, [boot_drive]
    jmp STAGE2_SEG:STAGE2_OFFSET


disk_error:
    mov si, error_msg

.err:
    lodsb
    test al, al
    jz $

    mov ah, 0x0E
    int 0x10
    jmp .err


boot_msg db "NovaOS booting...",13,10,0
error_msg db "Stage2 load error!",13,10,0

boot_drive db 0


times 510-($-$$) db 0
dw 0xAA55