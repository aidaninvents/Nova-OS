; NovaOS UEFI loader part C: handoff + ExitBootServices + jump
    mov rax, [rel fb_base]
    mov [HANDOFF + 48], rax          ; qword fb base
    mov eax, [rel best_ppsl]
    shl rax, 2
    mov [HANDOFF + 40], rax          ; qword pitch
    mov eax, [rel best_w]
    mov [HANDOFF + 24], rax          ; qword width
    mov eax, [rel best_h]
    mov [HANDOFF + 32], rax          ; qword height
    mov dword [HANDOFF + 20], 0x504F474E  ; 'NGOP'
    mov rax, [rel fb_base]
    mov [HANDOFF], eax               ; BIOS mirror dwords
    mov eax, [rel best_ppsl]
    shl eax, 2
    mov [HANDOFF + 4], eax
    mov eax, [rel best_w]
    mov [HANDOFF + 8], eax
    mov eax, [rel best_h]
    mov [HANDOFF + 12], eax
    mov dword [HANDOFF + 16], 32
    mov eax, [rel best_fmt]          ; 1=BGR => flags bit0
    cmp eax, 1
    sete al
    movzx eax, al
    or eax, 2                        ; bit1 = UEFI source
    mov rax, [rel sys_table]
    mov rcx, [rax + 64]
    lea rdx, [rel msg_jump]
    sub rsp, 32
    call [rcx + 8]
    add rsp, 32
    call exit_boot_services
    test rax, rax
    jnz near .fail_bs
    ; identity tables, clear all 6 pages (PML4, PDPT, PD0-3 = 24 KiB)
    mov rdi, PT_PML4
    mov rcx, (4096 * 6) / 8
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
    ; If fb_base is >= 4GB, map it in PT_PDPT
    mov r8, [rel fb_base]
    mov rdx, 0x100000000
    cmp r8, rdx
    jb .fb_mapped
    mov rax, r8
    shr rax, 30
    and eax, 0x1FF
    push rax
    mov eax, 0x80000001
    cpuid
    test edx, 1 << 26
    pop rax
    jnz .map_1gb
    mov rdi, 0x8000
    mov ecx, 512
    xor eax, eax
    rep stosq
    mov rax, r8
    shr rax, 30
    and eax, 0x1FF
    mov qword [PT_PDPT + rax*8], 0x8000 | 0x03
    mov rax, r8
    shr rax, 21
    and eax, 0x1FF
    lea rdi, [0x8000 + rax*8]
    mov rsi, r8
    and rsi, ~0x1FFFFF
    mov ecx, 16
.fb_2mb_loop:
    mov rax, rsi
    or rax, 0x83
    mov [rdi], rax
    add rdi, 8
    add rsi, 0x200000
    dec ecx
    jnz .fb_2mb_loop
    jmp .fb_mapped
.map_1gb:
    mov rsi, r8
    and rsi, ~0x3FFFFFFF
    or rsi, 0x83
    mov [PT_PDPT + rax*8], rsi
.fb_mapped:
    mov rax, PT_PML4
    mov cr3, rax
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
