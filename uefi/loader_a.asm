; NovaOS UEFI loader part A: header + GOP enum (see loader.asm)
BITS 64
DEFAULT REL
%define IMAGE_BASE      0x140000000
%define SECTION_RVA     0x1000
%define BY_PROTOCOL     2
%define PixelBitMask    2
%define PixelBltOnly    3
%define PixelFormatMax  4
%define KERNEL_PHYS     0x10000
%define KERNEL_MAX      0x10000
%define FS_PHYS         0x20000
%define FS_MAX          0x80000
%define HANDOFF         0x9000
%define STACK_TOP       0x400000
%define PT_PML4         0xA000
%define PT_PDPT         0xB000
%define PT_PD0          0xC000
%define MAX_GOP_WIDTH   2560
%define MAX_GOP_HEIGHT  1600
%define EFI_FILE_MODE_READ  0x1
%define EFI_FILE_READ_ONLY  0x1
%define EFI_BUFFER_TOO_SMALL 0x8000000000000005
section .text vstart=(IMAGE_BASE + SECTION_RVA)
efi_main:
    push rbx
    push rbp
    push rsi
    push rdi
    push r12
    push r13
    push r14
    push r15
    sub rsp, 0x60
    mov [rel img_handle], rcx
    mov [rel sys_table], rdx
    mov rcx, [rdx + 64]
    lea rdx, [rel msg_hello]
    call [rcx + 8]
    mov rax, [rel sys_table]
    mov rax, [rax + 88]
    mov [rel boot_svc], rax
    test rax, rax
    jz near .fail_bs
    lea rcx, [rel guid_gop]
    mov rbx, [rel boot_svc]
    mov edx, BY_PROTOCOL
    xor r8d, r8d
    lea r9, [rel tmp_size]
    mov qword [rel tmp_size], 0
    sub rsp, 32
    mov qword [rsp + 32], 0
    call [rbx + 176]
    add rsp, 32
    mov rdx, EFI_BUFFER_TOO_SMALL
    cmp rax, rdx
    jne near .fail_bs
    mov rax, [rel tmp_size]
    test rax, rax
    jz near .fail_bs
    cmp rax, 4096
    ja near .fail_bs
