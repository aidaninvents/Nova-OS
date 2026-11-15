; Part 2/4: handoff + ExitBootServices + page tables + jump
    mov rax, [rel fb_base]
    mov [HANDOFF], rax
    mov eax, [rel best_ppsl]
    shl rax, 2
    mov [HANDOFF + 8], rax
    mov eax, [rel best_w]
    mov [HANDOFF + 16], rax
    mov eax, [rel best_h]
    mov [HANDOFF + 24], rax
    mov qword [HANDOFF + 32], 32
    mov qword [HANDOFF + 40], 2
    mov eax, [rel best_fmt]
    cmp eax, 1
    sete al
    movzx eax, al
    mov [HANDOFF + 48], rax
    mov qword [HANDOFF + 56], 0
    mov eax, [rel fb_base]
    mov [0x9000], eax
    mov eax, [rel best_ppsl]
    shl eax, 2
    mov [0x9004], eax
    mov eax, [rel best_w]
    mov [0x9008], eax
    mov eax, [rel best_h]
    mov [0x900C], eax
    mov dword [0x9010], 32
    call exit_boot_services
    test rax, rax
    jnz near .fail_bs
    mov rdi, PT_PML4
    mov rcx, 4096/8
    xor eax, eax
    rep stosq
    mov qword [PT_PML4], PT_PDPT | 0x03
    mov qword [PT_PDPT + 0*8], PT_PD0 | 0x03
    mov qword [PT_PDPT + 1*8], (PT_PD0 + 0x1000) | 0x03
    mov qword [PT_PDPT + 2*8], (PT_PD0 + 0x2000) | 0x03
    mov qword [PT_PDPT + 3*8], (PT_PD0 + 0x3000) | 0x03
    xor ecx, ecx
.pd_loop:
    mov rdi, PT_PD0
    mov eax, ecx
    shl rax, 12
    add rdi, rax
    mov rax, rcx
    shl rax, 30
    mov edx, 512
.pte_loop:
    mov rsi, rax
    or rsi, 0x83
    mov [rdi], rsi
    add rdi, 8
    add rax, 0x200000
    dec edx
    jnz .pte_loop
    inc ecx
    cmp ecx, 4
    jb .pd_loop
    mov rax, PT_PML4
    mov cr3, rax
    mov rax, [rel sys_table]
    mov rcx, [rax + 64]
    lea rdx, [rel msg_jump]
    push rax
    sub rsp, 32
    call [rcx + 8]
    add rsp, 32
    pop rax
    mov rsp, STACK_TOP
    mov rax, KERNEL_PHYS
    jmp rax
.fail_nomode:
    mov rax, [rel sys_table]
    mov rcx, [rax + 64]
    lea rdx, [rel msg_nogop]
    call [rcx + 8]
    jmp .fail_halt
.fail_fs:
    mov rax, [rel sys_table]
    mov rcx, [rax + 64]
    lea rdx, [rel msg_nofs]
    call [rcx + 8]
    jmp .fail_halt
.fail_bs:
    mov rax, [rel sys_table]
    mov rcx, [rax + 64]
    lea rdx, [rel msg_fail]
    call [rcx + 8]
.fail_halt:
    add rsp, 0x60
    pop r15
    pop r14
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rbp
    pop rbx
    mov eax, 1
    ret
print_dec:
    push rbx
    push rsi
    push rdi
    sub rsp, 48
    lea rsi, [rsp + 40]
    mov word [rsi], 0
    mov ebx, 10
    test eax, eax
    jnz .pd_loop
    dec rsi
    dec rsi
    mov word [rsi], '0'
    jmp .pd_out
.pd_loop:
    xor edx, edx
    div ebx
    add dl, '0'
    dec rsi
    dec rsi
    mov [rsi], dx
    test eax, eax
    jnz .pd_loop
.pd_out:
    mov rax, [rel sys_table]
    mov rcx, [rax + 64]
    mov rdx, rsi
    call [rcx + 8]
    add rsp, 48
    pop rdi
    pop rsi
    pop rbx
    ret
