; Part 3/4: payload loading + read_all + ExitBootServices
%define EFI_FILE_MODE_READ 0x1
%define EFI_FILE_READ_ONLY 0x1
load_payloads:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 0x40
    mov rax, [rel boot_svc]
    mov rcx, [rel img_handle]
    lea rdx, [rel guid_loaded]
    lea r8, [rel loaded_ptr]
    sub rsp, 32
    call [rax + 152]
    add rsp, 32
    test rax, rax
    jnz .lp_fail
    mov rax, [rel loaded_ptr]
    mov rcx, [rax + 32]
    mov rax, [rel boot_svc]
    lea rdx, [rel guid_fs]
    lea r8, [rel fs_ptr]
    sub rsp, 32
    call [rax + 152]
    add rsp, 32
    test rax, rax
    jnz .lp_fail
    mov rax, [rel fs_ptr]
    lea rdx, [rel vol_ptr]
    sub rsp, 32
    call [rax + 8]
    add rsp, 32
    test rax, rax
    jnz .lp_fail
    mov rax, [rel vol_ptr]
    lea rdx, [rel path_kernel]
    lea r8, [rel fh_kernel]
    sub rsp, 48
    mov qword [rsp + 32], EFI_FILE_MODE_READ
    mov qword [rsp + 40], EFI_FILE_READ_ONLY
    call [rax + 8]
    add rsp, 48
    test rax, rax
    jnz .lp_fail
    mov rcx, [rel fh_kernel]
    mov rdx, KERNEL_PHYS
    mov r8, KERNEL_MAX
    call rel read_all
    test rax, rax
    jnz .lp_fail
    mov [rel kernel_size], r8
    mov rax, [rel vol_ptr]
    lea rdx, [rel path_fs]
    lea r8, [rel fh_fs]
    sub rsp, 48
    mov qword [rsp + 32], EFI_FILE_MODE_READ
    mov qword [rsp + 40], EFI_FILE_READ_ONLY
    call [rax + 8]
    add rsp, 48
    test rax, rax
    jnz .lp_fail
    mov rcx, [rel fh_fs]
    mov rdx, FS_PHYS
    mov r8, FS_MAX
    call rel read_all
    test rax, rax
    jnz .lp_fail
    cmp dword [FS_PHYS], 0x53464E56
    jne .lp_fail
    xor eax, eax
    add rsp, 0x40
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.lp_fail:
    mov eax, 1
    add rsp, 0x40
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
read_all:
    push rbx
    push r12
    push r13
    push r15
    sub rsp, 32
    mov rbx, rcx
    mov r12, rdx
    mov r13, r8
    xor r15d, r15d
.ra_loop:
    mov rax, r13
    sub rax, r15
    jbe .ra_done
    cmp rax, 65536
    jbe .ra_chunk
    mov rax, 65536
.ra_chunk:
    mov [rel io_size], rax
    mov rcx, rbx
    lea rdx, [rel io_size]
    mov r8, r12
    add r8, r15
    sub rsp, 32
    call [rbx + 32]
    add rsp, 32
    test rax, rax
    jnz .ra_fail
    mov rax, [rel io_size]
    test rax, rax
    jz .ra_done
    add r15, rax
    jmp .ra_loop
.ra_done:
    mov r8, r15
    xor eax, eax
    add rsp, 32
    pop r15
    pop r13
    pop r12
    pop rbx
    ret
.ra_fail:
    mov eax, 1
    add rsp, 32
    pop r15
    pop r13
    pop r12
    pop rbx
    ret
exit_boot_services:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 0x20
    mov r14d, 8
    mov rax, [rel boot_svc]
    mov rbx, rax
.ebs_real:
    mov qword [rel mmap_size], 0
    lea rcx, [rel mmap_size]
    xor edx, edx
    xor r8d, r8d
    lea r9, [rel mmap_key]
    sub rsp, 64
    lea rax, [rel mmap_dsize]
    mov [rsp + 32], rax
    lea rax, [rel mmap_dver]
    mov [rsp + 40], rax
    call [rbx + 56]
    add rsp, 64
    mov rax, [rel mmap_size]
    add rax, 8*48
    mov [rel mmap_size], rax
    mov rax, [rel boot_svc]
    xor ecx, ecx
    mov rdx, [rel mmap_size]
    lea r8, [rel mmap_ptr]
    sub rsp, 32
    call [rax + 128]
    add rsp, 32
    test rax, rax
    jnz .ebs_fail
    lea rcx, [rel mmap_size]
    mov rdx, [rel mmap_ptr]
    lea r8, [rel mmap_key]
    lea r9, [rel mmap_dsize]
    sub rsp, 64
    lea rax, [rel mmap_dver]
    mov [rsp + 32], rax
    call [rbx + 56]
    add rsp, 64
    test rax, rax
    jnz .ebs_fail
    mov rax, [rel boot_svc]
    mov rcx, [rel img_handle]
    mov rdx, [rel mmap_key]
    sub rsp, 32
    call [rax + 216]
    add rsp, 32
    test rax, rax
    jz .ebs_ok
    mov rax, [rel boot_svc]
    mov rcx, [rel mmap_ptr]
    sub rsp, 32
    call [rax + 136]
    add rsp, 32
    dec r14d
    jnz .ebs_real
.ebs_fail:
    mov eax, 1
    add rsp, 0x20
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.ebs_ok:
    xor eax, eax
    add rsp, 0x20
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
