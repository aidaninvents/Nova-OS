; =============================================================================
; chrome.asm -> chrome.nosp ("The First Web Browser Made for ASM")
; Standalone, zero-dependency, position-independent x86_64 Assembly Browser
; Engine for NovaOS and any external AI / OS Host (System V AMD64 ABI).
;
; Build:
;   nasm -f bin port/chrome_asm/chrome.asm -o build/chrome.nosp
;
; Host API Table (passed to chrome_asm_init in RDI):
;   [RDI + 0x00] fn draw_rect(x:edi, y:esi, w:edx, h:ecx, rgb:r8d)
;   [RDI + 0x08] fn draw_text(x:edi, y:esi, text:rdx, rgb:ecx)
;   [RDI + 0x10] fn net_fetch(url:rdi, out_buf:rsi, max_len:edx) -> rax=len
;   [RDI + 0x18] fn log_msg(text:rdi)
;
; Box Record Layout (NVBX, 64 bytes per box):
;   +0x00 (u16) x
;   +0x02 (u16) y
;   +0x04 (u16) w
;   +0x06 (u16) h
;   +0x08 (u32) bg_color (0x00RRGGBB)
;   +0x0C (u32) fg_color (0x00RRGGBB)
;   +0x10 (u8)  link_id  (0 = static box/card/input, 1..N = clickable link)
;   +0x11 (u8)  flags    (bit 0 = border, bit 1 = link underline)
;   +0x12 (46B) text     (null-terminated ASCII label)
; =============================================================================

BITS 64
ORG 0

; -----------------------------------------------------------------------------
; 0x0000: NOSP / ASMBROWS Portable Header (64 bytes)
; -----------------------------------------------------------------------------
header:
    db "NOSP"                       ; +0x00: NovaOS Portable App Signature
    dd 1                            ; +0x04: Format version 1
    db "ASMBROWS"                   ; +0x08: Portable ASM Browser Magic
    dd 0x00010000                   ; +0x10: Browser ABI v1.0
    dd 64                           ; +0x14: NVBX box struct size (64 bytes)
    dq chrome_asm_init              ; +0x18: RDI = host_api_table
    dq chrome_asm_parse_html        ; +0x20: RDI=html, RSI=len, RDX=boxes, RCX=max -> RAX=count
    dq chrome_asm_render            ; +0x28: RDI=boxes, RSI=count
    dq chrome_asm_on_click          ; +0x30: RDI=boxes, RSI=count, RDX=mx, RCX=my -> RAX=link_id
    dq chrome_asm_navigate          ; +0x38: RDI=url, RSI=html_buf, RDX=boxes, RCX=max -> RAX=count

; -----------------------------------------------------------------------------
; Host API Table Storage (PIC-relative)
; -----------------------------------------------------------------------------
host_draw_rect: dq 0
host_draw_text: dq 0
host_net_fetch: dq 0
host_log_msg:   dq 0

; -----------------------------------------------------------------------------
; chrome_asm_init(RDI = host_api_table)
; -----------------------------------------------------------------------------
chrome_asm_init:
    test rdi, rdi
    jz .init_done
    mov rax, [rdi + 0x00]
    mov [rel host_draw_rect], rax
    mov rax, [rdi + 0x08]
    mov [rel host_draw_text], rax
    mov rax, [rdi + 0x10]
    mov [rel host_net_fetch], rax
    mov rax, [rdi + 0x18]
    mov [rel host_log_msg], rax
.init_done:
    xor eax, eax
    ret

; -----------------------------------------------------------------------------
; chrome_asm_parse_html(RDI=html, RSI=len, RDX=out_boxes, RCX=max_boxes) -> RAX=count
; Pure x86_64 ASM HTML-to-Box DOM parser:
;   Extracts <title>, <h1>..<h3>, <p>, <button>, <input>, <a href="...">
;   and lays them out as 64-byte NVBX boxes with auto-wrapping Y coordinates.
; -----------------------------------------------------------------------------
chrome_asm_parse_html:
    push rbx
    push rbp
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi                    ; r12 = html cursor
    lea r13, [rdi + rsi]            ; r13 = html end
    mov r14, rdx                    ; r14 = out_boxes base
    mov r15, rcx                    ; r15 = max_boxes
    xor ebp, ebp                    ; ebp = box_count
    mov ebx, 132                    ; ebx = current layout Y (starts below toolbar)
    mov dword [rel parse_link_seq], 1

.scan_loop:
    cmp rbp, r15
    jae .parse_done
    cmp r12, r13
    jae .parse_done

    mov al, [r12]
    cmp al, '<'
    je .handle_tag
    inc r12
    jmp .scan_loop

.handle_tag:
    inc r12                         ; skip '<'
    cmp r12, r13
    jae .parse_done

    ; Check <a ...> -> clickable link box (blue pill)
    mov al, [r12]
    or al, 0x20
    cmp al, 'a'
    jne .chk_h
    mov cl, [r12 + 1]
    cmp cl, ' '
    je .is_link
    cmp cl, '>'
    je .is_link
    jmp .skip_tag

.is_link:
    mov r8d, 0x002563EB             ; bg = #2563EB
    mov r9d, 0x00FFFFFF             ; fg = #FFFFFF
    mov r10d, 3                     ; flags = border + underline
    mov r11d, [rel parse_link_seq]  ; link_id = 1..N
    inc dword [rel parse_link_seq]
    jmp .extract_tag_text

.chk_h:
    cmp al, 'h'
    jne .chk_p
    mov cl, [r12 + 1]
    cmp cl, '1'
    jb .chk_p
    cmp cl, '3'
    ja .chk_p
    mov r8d, 0x000F172A             ; bg = #0F172A (dark heading banner)
    mov r9d, 0x0034D399             ; fg = #34D399
    mov r10d, 1                     ; flags = border
    xor r11d, r11d                  ; link_id = 0
    jmp .extract_tag_text

.chk_p:
    cmp al, 'p'
    jne .chk_btn
    mov cl, [r12 + 1]
    cmp cl, '>'
    je .is_para
    cmp cl, ' '
    jne .chk_btn
.is_para:
    mov r8d, 0x00F8FAFC             ; bg = #F8FAFC (light card)
    mov r9d, 0x000F172A             ; fg = #0F172A
    mov r10d, 1                     ; flags = border
    xor r11d, r11d
    jmp .extract_tag_text

.chk_btn:
    cmp al, 'b'
    jne .chk_input
    mov cl, [r12 + 1]
    or cl, 0x20
    cmp cl, 'u'
    jne .skip_tag
    mov r8d, 0x001A73E8             ; bg = #1A73E8
    mov r9d, 0x00FFFFFF             ; fg = #FFFFFF
    mov r10d, 1
    mov r11d, [rel parse_link_seq]
    inc dword [rel parse_link_seq]
    jmp .extract_tag_text

.chk_input:
    cmp al, 'i'
    jne .skip_tag
    mov cl, [r12 + 1]
    or cl, 0x20
    cmp cl, 'n'
    jne .skip_tag
    ; Render <input> as an empty bordered input box
    mov r8d, 0x00FFFFFF
    mov r9d, 0x0064748B
    mov r10d, 1
    xor r11d, r11d
    call .emit_box_header
    lea rdi, [rax + 0x12]
    mov dword [rdi], '[Inp'
    mov dword [rdi + 4], 'ut B'
    mov word [rdi + 8], 'ox'
    mov word [rdi + 10], ']'
    inc rbp
    add ebx, 40
    jmp .skip_tag

.extract_tag_text:
    ; Advance r12 to '>'
.find_gt:
    cmp r12, r13
    jae .parse_done
    mov al, [r12]
    inc r12
    cmp al, '>'
    jne .find_gt

    ; Emit box header and copy inner text until '<' (max 44 chars)
    call .emit_box_header           ; rax = box pointer
    lea rdi, [rax + 0x12]
    xor ecx, ecx
.copy_txt:
    cmp r12, r13
    jae .finish_box
    mov al, [r12]
    cmp al, '<'
    je .finish_box
    cmp al, 10
    je .ws_norm
    cmp al, 13
    je .ws_norm
    cmp al, 9
    je .ws_norm
    cmp al, 32
    jb .next_ch
    cmp al, 126
    ja .next_ch
    jmp .store_ch
.ws_norm:
    mov al, ' '
.store_ch:
    cmp ecx, 44
    jae .next_ch
    mov [rdi + rcx], al
    inc ecx
.next_ch:
    inc r12
    jmp .copy_txt

.finish_box:
    mov byte [rdi + rcx], 0
    test ecx, ecx
    jz .scan_loop                   ; skip empty boxes
    inc rbp
    add ebx, 40
    cmp ebx, 680
    jae .parse_done
    jmp .scan_loop

.skip_tag:
    cmp r12, r13
    jae .parse_done
    mov al, [r12]
    inc r12
    cmp al, '>'
    jne .skip_tag
    jmp .scan_loop

; Internal helper: writes NVBX header at r14 + rbp*64 -> returns ptr in rax
.emit_box_header:
    mov rax, rbp
    shl rax, 6
    add rax, r14
    mov word [rax + 0x00], 40       ; x = 40
    mov word [rax + 0x02], bx       ; y = current Y
    mov word [rax + 0x04], 660      ; w = 660
    mov word [rax + 0x06], 34       ; h = 34
    mov dword [rax + 0x08], r8d     ; bg_color
    mov dword [rax + 0x0C], r9d     ; fg_color
    mov byte [rax + 0x10], r11b     ; link_id
    mov byte [rax + 0x11], r10b     ; flags
    ret

.parse_done:
    mov eax, ebp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx
    ret

parse_link_seq: dd 1

; -----------------------------------------------------------------------------
; chrome_asm_render(RDI = boxes_ptr, RSI = box_count)
; Calls host draw_rect & draw_text for every NVBX box.
; -----------------------------------------------------------------------------
chrome_asm_render:
    push rbx
    push r12
    push r13
    push r14

    mov r12, rdi                    ; r12 = boxes_ptr
    mov r13, rsi                    ; r13 = box_count
    xor r14d, r14d                  ; r14 = index

.ren_loop:
    cmp r14, r13
    jae .ren_done
    mov rbx, r14
    shl rbx, 6
    add rbx, r12                    ; rbx = current box

    mov rax, [rel host_draw_rect]
    test rax, rax
    jz .ren_text

    ; Border if flags & 1
    test byte [rbx + 0x11], 1
    jz .ren_fill
    movzx edi, word [rbx + 0x00]
    dec edi
    movzx esi, word [rbx + 0x02]
    dec esi
    movzx edx, word [rbx + 0x04]
    add edx, 2
    movzx ecx, word [rbx + 0x06]
    add ecx, 2
    mov r8d, 0x0094A3B8
    call rax

.ren_fill:
    mov rax, [rel host_draw_rect]
    movzx edi, word [rbx + 0x00]
    movzx esi, word [rbx + 0x02]
    movzx edx, word [rbx + 0x04]
    movzx ecx, word [rbx + 0x06]
    mov r8d, [rbx + 0x08]
    call rax

.ren_text:
    mov rax, [rel host_draw_text]
    test rax, rax
    jz .ren_next
    movzx edi, word [rbx + 0x00]
    add edi, 8
    movzx esi, word [rbx + 0x02]
    add esi, 8
    lea rdx, [rbx + 0x12]
    mov ecx, [rbx + 0x0C]
    call rax

.ren_next:
    inc r14
    jmp .ren_loop

.ren_done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; -----------------------------------------------------------------------------
; chrome_asm_on_click(RDI=boxes_ptr, RSI=box_count, RDX=mx, RCX=my) -> RAX=link_id
; -----------------------------------------------------------------------------
chrome_asm_on_click:
    xor eax, eax
    xor r8d, r8d                    ; index
.clk_loop:
    cmp r8, rsi
    jae .clk_none
    mov r9, r8
    shl r9, 6
    add r9, rdi

    movzx r10d, byte [r9 + 0x10]    ; link_id
    test r10d, r10d
    jz .clk_next

    movzx r11d, word [r9 + 0x00]    ; x
    cmp edx, r11d
    jb .clk_next
    movzx eax, word [r9 + 0x04]     ; w
    add r11d, eax
    cmp edx, r11d
    jae .clk_next

    movzx r11d, word [r9 + 0x02]    ; y
    cmp ecx, r11d
    jb .clk_next
    movzx eax, word [r9 + 0x06]     ; h
    add r11d, eax
    cmp ecx, r11d
    jae .clk_next

    mov eax, r10d                   ; hit! return link_id
    ret

.clk_next:
    inc r8
    jmp .clk_loop

.clk_none:
    xor eax, eax
    ret

; -----------------------------------------------------------------------------
; chrome_asm_navigate(RDI=url, RSI=html_buf, RDX=boxes_buf, RCX=max_boxes) -> RAX=count
; -----------------------------------------------------------------------------
chrome_asm_navigate:
    push rbx
    push r12
    push r13
    push r14
    mov r12, rsi                    ; html_buf
    mov r13, rdx                    ; boxes_buf
    mov r14, rcx                    ; max_boxes

    mov rax, [rel host_net_fetch]
    test rax, rax
    jz .nav_fail
    mov rsi, r12
    mov edx, 65535
    call rax                        ; rax = fetched html_len
    test rax, rax
    jle .nav_fail

    mov rdi, r12
    mov rsi, rax
    mov rdx, r13
    mov rcx, r14
    call chrome_asm_parse_html
    mov rbx, rax                    ; box_count

    mov rdi, r13
    mov rsi, rbx
    call chrome_asm_render
    mov rax, rbx
    jmp .nav_ret

.nav_fail:
    xor eax, eax
.nav_ret:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
