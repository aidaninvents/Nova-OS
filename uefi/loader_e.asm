; NovaOS UEFI loader part E: ExitBootServices + data
exit_boot_services:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 0x20
    mov rax, [rel boot_svc]
    mov rbx, rax
    mov r14d, 8
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
msg_hello   dw 'N','o','v','a','O','S',' ','U','E','F','I',' ','l','o','a','d','e','r',13,10,0
msg_mode    dw 'G','O','P',' ','m','o','d','e',':',' ',0
msg_x       dw 'x',0
msg_nl      dw 13,10,0
msg_jump    dw 'S','t','a','r','t','i','n','g',' ','k','e','r','n','e','l','.','.','.',13,10,0
msg_fail    dw 'U','E','F','I',' ','b','o','o','t',' ','f','a','i','l','u','r','e','.',13,10,0
msg_nogop   dw 'N','o',' ','s','u','i','t','a','b','l','e',' ','G','O','P',' ','m','o','d','e','.',13,10,0
msg_nofs    dw 'P','a','y','l','o','a','d',' ','m','i','s','s','i','n','g','.',13,10,0
path_kernel dw 92,'E','F','I',92,'N','O','V','A',92,'K','E','R','N','E','L','.','B','I','N',0
path_fs     dw 92,'E','F','I',92,'N','O','V','A',92,'N','O','V','A','F','S','.','B','I','N',0
guid_gop    db 0xDE,0xA9,0x42,0x90,0xDC,0x23,0x38,0x4A,0x96,0xFB,0x7A,0xDE,0xD0,0x80,0x51,0x6A
guid_fs     db 0x22,0x5B,0x4E,0x96,0x59,0x64,0xD2,0x11,0x8E,0x39,0x00,0xA0,0xC9,0x69,0x72,0x3B
guid_loaded db 0xA1,0x31,0x1B,0x5B,0x62,0x95,0xD2,0x11,0x8E,0x3F,0x00,0xA0,0xC9,0x69,0x72,0x3B
img_handle  dq 0
sys_table   dq 0
boot_svc    dq 0
gop_ptr     dq 0
gop_mode    dq 0
gop_max     dd 0, 0
best_w      dd 0
best_h      dd 0
best_fmt    dd 0
best_ppsl   dd 0
fb_base     dq 0
fb_size     dq 0
tmp_size    dq 0
tmp_ptr     dq 0
tmp_info    dq 0
tmp_isz     dq 0
loaded_ptr  dq 0
fs_ptr      dq 0
vol_ptr     dq 0
fh_kernel   dq 0
fh_fs       dq 0
kernel_size dq 0
io_size     dq 0
mmap_ptr    dq 0
mmap_size   dq 0
mmap_key    dq 0
mmap_dsize  dq 0
mmap_dver   dd 0, 0
times 0x1000 - ($ - $$) db 0
