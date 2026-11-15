; NovaOS UEFI loader part B: pool alloc + mode loop + SetMode
    mov rax, [rel boot_svc]
    xor ecx, ecx
    mov rdx, [rel tmp_size]
    lea r8, [rel tmp_ptr]
    sub rsp, 32
    call [rax + 128]
    add rsp, 32
    test rax, rax
    jnz near .fail_bs
    mov rax, [rel tmp_ptr]
    test rax, rax
    jz near .fail_bs
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
    test rax, rax
    jz near .fail_bs
    mov rax, [rax + 8]
    mov [rel gop_mode], rax
    test rax, rax
    jz near .fail_bs
    mov ecx, [rax]
    mov [rel gop_max], ecx
    xor r14d, r14d
    xor r15d, r15d
    mov dword [rel best_w], 0
    mov dword [rel best_h], 0
    xor ebx, ebx
.mode_loop:
    cmp ebx, [rel gop_max]
    jae .mode_done
    mov rcx, [rel gop_ptr]
    mov edx, ebx
    lea r8, [rel tmp_isz]
    lea r9, [rel tmp_info]
    sub rsp, 32
    call [rcx + 8]
    add rsp, 32
    test rax, rax
    jnz .mode_next
    mov rsi, [rel tmp_info]
    test rsi, rsi
    jz .mode_next
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
    mov rcx, [rel gop_ptr]
    mov edx, r14d
    sub rsp, 32
    call [rcx + 16]
    add rsp, 32
    test rax, rax
    jnz near .fail_nomode
    mov rax, [rel gop_ptr]
    mov rax, [rax + 8]
    mov [rel gop_mode], rax
    test rax, rax
    jz near .fail_nomode
    mov rcx, [rax + 8]
    test rcx, rcx
    jz near .fail_nomode
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
    test rdx, rdx
    jz near .fail_nomode
    mov rdx, [rax + 32]
    mov [rel fb_size], rdx
    mov eax, [rel best_ppsl]
    shl rax, 2
    mov rcx, [rel best_h]
    mul rcx
    test rdx, rdx
    jnz near .fail_nomode
    cmp qword [rel fb_size], 0
    jz .fb_size_ok
    cmp rax, [rel fb_size]
    jbe .fb_size_ok
    mov [rel fb_size], rax
.fb_size_ok:
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
