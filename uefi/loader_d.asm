; NovaOS UEFI loader part D: payload file loading
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
    test rax, rax
    jz .lp_fail
    mov rcx, [rax + 32]
    mov rax, [rel boot_svc]
    lea rdx, [rel guid_fs]
    lea r8, [rel fs_ptr]
    sub rsp, 32
    call [rax + 152]
    add rsp, 32
    test rax, rax
    jnz .lp_fail
    mov rcx, [rel fs_ptr]
    test rcx, rcx
    jz .lp_fail
    lea rdx, [rel vol_ptr]
    sub rsp, 32
    call [rcx + 8]
    add rsp, 32
    test rax, rax
    jnz .lp_fail
    mov rcx, [rel vol_ptr]
    lea rdx, [rel fh_kernel]
    lea r8, [rel path_kernel]
    mov r9, EFI_FILE_MODE_READ
    sub rsp, 48
    mov qword [rsp + 32], EFI_FILE_READ_ONLY
    call [rcx + 8]
    add rsp, 48
    test rax, rax
    jnz .lp_fail
    mov rcx, [rel fh_kernel]
    mov rdx, KERNEL_PHYS
    mov r8, KERNEL_MAX
    call read_all
    test rax, rax
    jnz .lp_fail
    mov [rel kernel_size], r8
    cmp r8, 512
    jb .lp_fail
    mov rcx, [rel vol_ptr]
    lea rdx, [rel fh_fs]
    lea r8, [rel path_fs]
    mov r9, EFI_FILE_MODE_READ
    sub rsp, 48
    mov qword [rsp + 32], EFI_FILE_READ_ONLY
    call [rcx + 8]
    add rsp, 48
    test rax, rax
    jnz .lp_fail
    mov rcx, [rel fh_fs]
    mov rdx, FS_PHYS
    mov r8, FS_MAX
    call read_all
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
