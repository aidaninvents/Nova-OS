; NovaOS UEFI bootloader (x86-64 PE/COFF .efi, NASM)
; Part 1/4: headers + entry + GOP enumeration
BITS 64
DEFAULT REL
%define IMAGE_BASE      0x140000000
%define SECTION_RVA     0x1000
%define EFI_SUCCESS     0
%define BY_PROTOCOL     2
%define AllocatePages   2
%define EfiLoaderData   2
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
    lea rcx, [rel guid_gop]
    mov rbx, rax
    mov edx, BY_PROTOCOL
    xor r8d, r8d
    lea r9, [rel tmp_size]
    mov qword [rel tmp_size], 0
    sub rsp, 32
    mov qword [rsp + 32], 0
    call [rbx + 176]
    add rsp, 32
    cmp rax, 5
    jne near .fail_bs
    mov rax, [rel boot_svc]
    xor ecx, ecx
    mov rdx, [rel tmp_size]
    lea r8, [rel tmp_ptr]
    sub rsp, 32
    call [rax + 128]
    add rsp, 32
    test rax, rax
    jnz near .fail_bs
    mov rax, [rel boot_svc]
    lea rcx, [rel guid_gop]
    mov edx, BY_PROTOCOL
    xor r8d, r8d
    lea r9, [rel tmp_size]
    mov rbx, [rel tmp_ptr]
    sub rsp, 32
    mov [rsp + 32], rbx
    call [rax + 176]
    add rsp, 32
    test rax, rax
    jnz near .fail_bs
    mov rax, [rel boot_svc]
    mov rcx, [rel tmp_ptr]
    mov rcx, [rcx]
    lea rdx, [rel guid_gop]
    lea r8, [rel gop_ptr]
    sub rsp, 32
    call [rax + 152]
    add rsp, 32
    test rax, rax
    jnz near .fail_bs
    mov rax, [rel gop_ptr]
    mov rax, [rax + 8]
    mov [rel gop_mode], rax
    mov ecx, [rax]
    mov [rel gop_max], ecx
    xor r14d, r14d
    xor r15d, r15d
    xor ebx, ebx
.mode_loop:
    cmp ebx, [rel gop_max]
    jae .mode_done
    mov rax, [rel gop_ptr]
    mov edx, ebx
    lea r8, [rel tmp_isz]
    lea r9, [rel tmp_info]
    sub rsp, 32
    call [rax + 8]
    add rsp, 32
    test rax, rax
    jnz .mode_next
    mov rsi, [rel tmp_info]
    mov eax, [rsi + 4]
    mov edx, [rsi + 8]
    mov ecx, [rsi + 12]
    cmp ecx, PixelFormatMax
    jae .mode_next
    cmp ecx, PixelBitMask
    je .mode_next
    cmp ecx, PixelBltOnly
    je .mode_next
    cmp eax, 640
    jb .mode_next
    cmp edx, 400
    jb .mode_next
    cmp eax, MAX_GOP_WIDTH
    ja .mode_next
    cmp edx, MAX_GOP_HEIGHT
    ja .mode_next
    mov r10d, eax
    imul r10d, edx
    cmp r10d, r15d
    jbe .mode_next
    mov r15d, r10d
    mov r14d, ebx
    mov eax, [rsi + 4]
    mov [rel best_w], eax
    mov eax, [rsi + 8]
    mov [rel best_h], eax
    mov eax, [rsi + 12]
    mov [rel best_fmt], eax
    mov eax, [rsi + 16]
    mov [rel best_ppsl], eax
.mode_next:
    inc ebx
    jmp .mode_loop
.mode_done:
    test r15d, r15d
    jz near .fail_nomode
    mov rax, [rel gop_ptr]
    mov edx, r14d
    sub rsp, 32
    call [rax + 16]
    add rsp, 32
    test rax, rax
    jnz near .fail_nomode
    mov rax, [rel gop_ptr]
    mov rax, [rax + 8]
    mov [rel gop_mode], rax
    mov rcx, [rax + 8]
    mov edx, [rcx + 4]
    mov [rel best_w], edx
    mov edx, [rcx + 8]
    mov [rel best_h], edx
    mov edx, [rcx + 12]
    mov [rel best_fmt], edx
    mov edx, [rcx + 16]
    mov [rel best_ppsl], edx
    mov rdx, [rax + 24]
    mov [rel fb_base], rdx
    mov rdx, [rax + 32]
    mov [rel fb_size], rdx
    mov rax, [rel sys_table]
    mov rcx, [rax + 64]
    lea rdx, [rel msg_mode]
    call [rcx + 8]
    mov eax, [rel best_w]
    call print_dec
    mov rax, [rel sys_table]
    mov rcx, [rax + 64]
    lea rdx, [rel msg_x]
    call [rcx + 8]
    mov eax, [rel best_h]
    call print_dec
    mov rax, [rel sys_table]
    mov rcx, [rax + 64]
    lea rdx, [rel msg_nl]
    call [rcx + 8]
    call load_payloads
    test rax, rax
    jnz near .fail_fs
