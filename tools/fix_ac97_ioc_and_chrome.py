import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KERNEL_PATH = os.path.join(ROOT, "kernel.asm")

with open(KERNEL_PATH, "rb") as f:
    raw = f.read().decode("utf-8", errors="strict")

newline = "\r\n" if "\r\n" in raw else "\n"
src = raw.replace("\r\n", "\n")

def replace_exact(s, old, new, label):
    old_n = old.replace("\r\n", "\n")
    new_n = new.replace("\r\n", "\n")
    assert old_n in s, f"Missing: {label}"
    assert s.count(old_n) == 1, f"Multiple matches: {label}"
    print(f"[PATCH OK] {label}")
    return s.replace(old_n, new_n, 1)

# 1. Zero AUDIO_BDL & do NOT set BD_IOC on intermediate streaming BDL descriptors (only on EOF)
src = replace_exact(src, """.live_pre_aud:
    mov byte [aud_eof_flag], 0
    mov dword [aud_wraps], 0
    mov dword [aud_civ_prev], 0
    xor r12d, r12d              ; initial audio segments 0..3 (2.0s)
.live_pa_lp:
    mov ecx, r12d
    mov eax, ecx
    imul eax, 96000
    add eax, AUDIO_DMA_BUFFER
    mov rdi, rax
    push r12
    call net_fetch_audio_seg
    pop r12
    test eax, eax
    jle .live_pa_eof
    ; Fill AUDIO_BDL[r12d]
    mov edx, r12d
    imul edx, 96000
    add edx, AUDIO_DMA_BUFFER
    mov ebx, r12d
    shl ebx, 3
    add ebx, AUDIO_BDL
    mov [ebx + 0], edx
    shr eax, 1
    or eax, BD_IOC
    mov [ebx + 4], eax""", """.live_pre_aud:
    push rdi
    push rax
    push rcx
    mov rdi, AUDIO_BDL
    xor eax, eax
    mov ecx, 64
    rep stosd
    pop rcx
    pop rax
    pop rdi
    mov byte [aud_eof_flag], 0
    mov dword [aud_wraps], 0
    mov dword [aud_civ_prev], 0
    xor r12d, r12d              ; initial audio segments 0..3 (2.0s)
.live_pa_lp:
    mov ecx, r12d
    mov eax, ecx
    imul eax, 96000
    add eax, AUDIO_DMA_BUFFER
    mov rdi, rax
    push r12
    call net_fetch_audio_seg
    pop r12
    test eax, eax
    jle .live_pa_eof
    ; Fill AUDIO_BDL[r12d] (BD_IOC only when net_eof_flag == 1 so AC97 never halts mid-stream!)
    mov edx, r12d
    imul edx, 96000
    add edx, AUDIO_DMA_BUFFER
    mov ebx, r12d
    shl ebx, 3
    add ebx, AUDIO_BDL
    mov [ebx + 0], edx
    shr eax, 1
    cmp byte [net_eof_flag], 1
    jne .live_pa_no_ioc
    or eax, BD_IOC
.live_pa_no_ioc:
    mov [ebx + 4], eax""", "pre_aud_no_mid_ioc")

src = replace_exact(src, """    mov [edi + 0], edx
    shr eax, 1
    or eax, BD_IOC
    mov [edi + 4], eax
    inc dword [aud_next_seg]
    mov eax, [audio_bm]
    test eax, eax
    jz .lta_chk_eof
    lea edx, [eax + PO_LVI]
    mov al, bl
    out dx, al
    ; If DMA had just halted right before LVI bump & not paused, restart
    cmp byte [yt_video_paused], 1
    je .lta_chk_eof
    mov ebx, [audio_bm]
    lea edx, [ebx + PO_SR]
    in al, dx
    test al, 1
    jz .lta_chk_eof
    mov ax, 0x001C
    out dx, ax
    lea edx, [ebx + PO_CR]
    mov al, 1
    out dx, al""", """    mov [edi + 0], edx
    shr eax, 1
    cmp byte [net_eof_flag], 1
    jne .lta_no_ioc
    or eax, BD_IOC
.lta_no_ioc:
    mov [edi + 4], eax
    inc dword [aud_next_seg]
    mov eax, [audio_bm]
    test eax, eax
    jz .lta_chk_eof
    lea edx, [eax + PO_LVI]
    mov al, bl
    out dx, al
    ; Clear any latched status bits & auto-restart if DCH halted and not paused
    mov ebx, [audio_bm]
    lea edx, [ebx + PO_SR]
    in al, dx
    test al, 0x1C
    jz .lta_chk_dch
    push rax
    mov ax, 0x001C
    out dx, ax
    pop rax
.lta_chk_dch:
    cmp byte [yt_video_paused], 1
    je .lta_chk_eof
    test al, 1
    jz .lta_chk_eof
    lea edx, [ebx + PO_CR]
    mov al, 1
    out dx, al""", "live_topup_no_mid_ioc")

# 2. Chrome web_page_type 6 (\x16) for general Web Search Results (no Wikipedia Globe!)
src = replace_exact(src, """    cmp al, 0x11
    jb .flw_store_char
    cmp al, 0x15
    ja .flw_store_char""", """    cmp al, 0x11
    jb .flw_store_char
    cmp al, 0x16
    ja .flw_store_char""", "flw_allow_type6")

src = replace_exact(src, """    mov dword [text_fg_color], 0x000F172A
    mov byte [cursor_x], 5
    mov byte [cursor_y], 9
    mov byte [term_left_col], 5
    mov rsi, web_response_buf""", """    mov byte [text_transparent_bg], 1
    mov dword [text_fg_color], 0x000F172A
    mov byte [cursor_x], 5
    mov byte [cursor_y], 9
    mov byte [term_left_col], 5
    mov rsi, web_response_buf""", "chrome_transparent_web_text")

src = replace_exact(src, """    cmp al, 5
    je .draw_ozone_gpu_page

    ; web_page_type == 2 (Wikipedia / Article): Render TrueColor Wikipedia Globe & Photo Card (X=715, Y=175, W=245, H=230)""", """    cmp al, 5
    je .draw_ozone_gpu_page
    cmp al, 6
    je .draw_web_search_card

    ; web_page_type == 2 (Wikipedia / Article): Render TrueColor Wikipedia Globe & Photo Card (X=715, Y=175, W=245, H=230)""", "chrome_dispatch_type6")

src = replace_exact(src, """    mov dword [text_fg_color], 0x000F172A
    mov byte [cursor_x], 61
    mov byte [cursor_y], 18
    mov rsi, str_wiki_img_caption
    call print
    call draw_mouse_cursor
    jmp .chrome_event_loop""", """    mov dword [text_fg_color], 0x000F172A
    mov byte [cursor_x], 61
    mov byte [cursor_y], 18
    mov rsi, str_wiki_img_caption
    call print
    call draw_mouse_cursor
    jmp .chrome_event_loop

.draw_web_search_card:
    mov eax, 715
    mov ebx, 175
    mov ecx, 245
    mov edx, 230
    mov esi, 0x003B82F6
    call draw_rect
    mov eax, 719
    mov ebx, 179
    mov ecx, 237
    mov edx, 222
    mov esi, 0x00EFF6FF
    call draw_rect
    mov eax, 755
    mov ebx, 210
    mov ecx, 165
    mov edx, 120
    mov esi, 0x001D4ED8
    call draw_rect
    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 65
    mov byte [cursor_y], 13
    mov rsi, str_web_badge_txt
    call print
    mov dword [text_fg_color], 0x000F172A
    mov byte [cursor_x], 61
    mov byte [cursor_y], 18
    mov rsi, str_web_img_caption
    call print
    call draw_mouse_cursor
    jmp .chrome_event_loop""", "chrome_draw_web_search_card")

src = replace_exact(src, """str_wiki_img_caption:""", """str_web_badge_txt:  db "WEB SEARCH",0
str_web_img_caption: db "[WEB] Live Results",0
str_wiki_img_caption:""", "add_web_card_strings")

with open(KERNEL_PATH, "wb") as f:
    f.write(src.replace("\n", newline).encode("utf-8"))
print("Applied AC97 IOC & Chrome web card fixes!")
