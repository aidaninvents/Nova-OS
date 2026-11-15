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
    assert old_n in s, f"Missing target block: {label}"
    assert s.count(old_n) == 1, f"Multiple matches for block: {label}"
    print(f"[PATCH OK] {label}")
    return s.replace(old_n, new_n, 1)

# 1. Chrome query preservation when opening YouTube search from Chrome omnibox
src = replace_exact(src, """.flw_exit:
    cmp byte [web_page_type], 1
    jne .flw_done_all
    call fetch_yt_live_feed
.flw_done_all:""", """.flw_exit:
    cmp byte [web_page_type], 1
    jne .flw_done_all
    push rsi
    push rdi
    mov rsi, chrome_query_buf
    mov rdi, yt_search_buf
    mov ecx, 35
    xor ebx, ebx
.flw_cp_ytq:
    lodsb
    stosb
    test al, al
    jz .flw_cp_done
    inc ebx
    dec ecx
    jnz .flw_cp_ytq
    mov byte [rdi], 0
.flw_cp_done:
    mov [yt_search_len], bl
    mov byte [yt_has_searched], 1
    pop rdi
    pop rsi
    call fetch_yt_live_feed
.flw_done_all:""", "flw_exit_sync_chrome_query")

# 2. Fetch live thumbnails right inside fetch_yt_live_feed
src = replace_exact(src, """.yt_rx_done:
    mov byte [yt_feed_loaded], 1
    pop r14
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rax
    ret""", """.yt_rx_done:
    mov byte [yt_feed_loaded], 1
    mov byte [yt_uploaded_active], 0
    call fetch_yt_all_thumbs
    pop r14
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rax
    ret

; Refresh 3 active 80x45 thumbnails into yt_thumb_buf_0..2 via e1000 UDP (or COM1 fallback)
fetch_yt_all_thumbs:
    push rax
    push rbx
    push rcx
    push rdi
    call e1000_init
    test eax, eax
    jz .th_com1_all
    xor ebx, ebx
.th_udp_loop:
    mov rdi, yt_thumb_buf_0
    cmp ebx, 1
    jne .th_chk2
    mov rdi, yt_thumb_buf_1
.th_chk2:
    cmp ebx, 2
    jne .th_do_udp
    mov rdi, yt_thumb_buf_2
.th_do_udp:
    mov al, 1                   ; CMD_GET_THUMB
    mov ah, bl                  ; slot 0..2
    xor ecx, ecx
    xor edx, edx
    mov r8d, 14400
    call net_fetch_batch
    cmp eax, 14400
    jne .th_com1_one
.th_next_slot:
    inc ebx
    cmp ebx, 3
    jb .th_udp_loop
    jmp .th_ptrs_ok
.th_com1_all:
    xor ebx, ebx
.th_com1_one:
    mov rdi, yt_thumb_buf_0
    cmp ebx, 1
    jne .tc_2
    mov rdi, yt_thumb_buf_1
.tc_2:
    cmp ebx, 2
    jne .tc_go
    mov rdi, yt_thumb_buf_2
.tc_go:
    push rbx
    mov al, bl
    call fetch_com1_thumb
    pop rbx
    inc ebx
    cmp ebx, 3
    jb .th_com1_one
.th_ptrs_ok:
    mov qword [yt_thumb_ptr_0], yt_thumb_buf_0
    mov qword [yt_thumb_ptr_1], yt_thumb_buf_1
    mov qword [yt_thumb_ptr_2], yt_thumb_buf_2
    mov byte [yt_thumbs_loaded], 1
    pop rdi
    pop rcx
    pop rbx
    pop rax
    ret

; AL = slot (0..2), RDI = dest 14400-byte buffer via COM1 YT_THUMB fallback
fetch_com1_thumb:
    push rax
    push rcx
    push rdx
    push rsi
    push r14
    add al, '0'
    mov [str_bridge_yt_thumb_idx], al
    call serial_flush_rx
    mov rsi, str_bridge_yt_thumb
    call serial_send_string
    xor r14d, r14d
    mov ecx, 250000
.fct_lp:
    mov dx, 0x3FD
    in al, dx
    test al, 1
    jnz .fct_b
    dec ecx
    jnz .fct_lp
    jmp .fct_done
.fct_b:
    mov dx, 0x3F8
    in al, dx
    cmp al, 0x04
    je .fct_done
    cmp r14d, 14400
    jae .fct_lp
    mov [rdi + r14], al
    inc r14d
    mov ecx, 80000
    jmp .fct_lp
.fct_done:
    pop r14
    pop rsi
    pop rdx
    pop rcx
    pop rax
    ret""", "fetch_yt_all_thumbs")

# 3. Replace play_real_video start + offline check with e1000 live streaming + seamless AC97 ring + fallback
src = replace_exact(src, """    ; Check which video is selected: Video 1 (seed == 0) uses Real 320x240->640x480 15fps HD Stream!
    cmp dword [yt_playing_seed], 0
    jne near .fallback_thumb_video

    ; Load real 19s 48kHz 16-bit stereo PCM audio (LBA 10000, 7125 sectors -> 0x00600000)
    mov eax, VIDEO_PCM_LBA
    mov ecx, VIDEO_PCM_SECTORS
    mov rdi, AUDIO_DMA_BUFFER
    call ata_read_sectors
    mov dword [audio_size], VIDEO_PCM_BYTES""", """    ; Map yt_playing_seed -> slot 0, 1, or 2
    xor eax, eax
    cmp dword [yt_playing_seed], 0
    je .slot_set
    inc eax
    cmp dword [yt_playing_seed], 64
    je .slot_set
    cmp dword [yt_playing_seed], 0x005A3C91
    je .slot_set
    inc eax
.slot_set:
    mov [yt_playing_slot], al
    mov byte [net_is_live_vid], 0

    ; Try live YouTube arbitrary-duration streaming via e1000 + UDP :8082!
    call e1000_init
    test eax, eax
    jz near .offline_fallback_select

    inc word [e1000_sess_id]
    jnz .sess_nz
    mov word [e1000_sess_id], 1
.sess_nz:
    mov dword [text_fg_color], 0x0038BDF8
    mov byte [cursor_x], 24
    mov byte [cursor_y], 17
    mov rsi, str_yt_connecting
    call print

    mov r13d, 220               ; Poll stream start up to ~20s (handles esc abort)
.wait_stream_ready:
    call yt_handle_input
    cmp eax, 1
    je near .video_stream_done

    call net_poll_start_video
    cmp eax, 1
    jne .wait_stream_next
    cmp byte [net_start_status], 1
    je .live_stream_go
    cmp byte [net_start_status], 2
    je near .offline_fallback_select
.wait_stream_next:
    mov ecx, 1500000
.ws_dly:
    pause
    dec ecx
    jnz .ws_dly
    dec r13d
    jnz .wait_stream_ready
    jmp .offline_fallback_select

.live_stream_go:
    mov byte [net_is_live_vid], 1
    ; Clear connecting text
    mov eax, 180
    mov ebx, 108
    mov ecx, 664
    mov edx, 484
    xor esi, esi
    call draw_rect

    ; Format real duration in str_yt_timecode + 8 (or "--:--" if 0)
    mov eax, [yt_stream_dur]
    test eax, eax
    jz .live_dur_unk
    mov rdi, str_yt_timecode + 8
    call fmt_mmss
    jmp .live_pre_aud
.live_dur_unk:
    mov dword [str_yt_timecode + 8], 0x2D2D3A2D
    mov byte [str_yt_timecode + 12], '-'

.live_pre_aud:
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
    mov [ebx + 4], eax
    inc r12d
    cmp byte [net_eof_flag], 1
    je .live_pa_eof_mark
    cmp r12d, 4
    jb .live_pa_lp
    jmp .live_pa_arm
.live_pa_eof:
.live_pa_eof_mark:
    mov byte [aud_eof_flag], 1
.live_pa_arm:
    mov [aud_next_seg], r12d
    mov eax, [audio_bm]
    test eax, eax
    jz .live_vid_start
    test r12d, r12d
    jz .live_vid_start
    call audio_reset_po
    mov ebx, r12d
    dec ebx
    call audio_arm_bdl

.live_vid_start:
    xor r14d, r14d              ; current frame 0..EOF
.live_frame_loop:
    call live_topup_audio

    mov ecx, r14d
    mov rdi, VIDEO_YUV_BUF
    call net_fetch_video_frame
    test eax, eax
    jle near .live_drain_done

    call draw_yuv420_320x240_2x

    ; Seek bar progress using real yt_total_frames (fallback 1800 if 0)
    mov eax, 176
    mov ebx, 600
    mov ecx, 674
    mov edx, 16
    mov esi, 0x000B0F19
    call draw_rect
    mov eax, 180
    mov ebx, 604
    mov ecx, 664
    mov edx, 8
    mov esi, 0x00334155
    call draw_rect

    mov ecx, [yt_total_frames]
    test ecx, ecx
    jnz .live_tf_ok
    mov ecx, 1800
.live_tf_ok:
    mov eax, r14d
    imul eax, 664
    xor edx, edx
    div ecx
    cmp eax, 664
    jbe .live_pw_ok
    mov eax, 664
.live_pw_ok:
    push rax
    mov ecx, eax
    test ecx, ecx
    jz .live_skip_red
    mov eax, 180
    mov ebx, 604
    mov edx, 8
    mov esi, 0x00FF0000
    call draw_rect
.live_skip_red:
    pop rax
    add eax, 176
    mov ebx, 601
    mov ecx, 8
    mov edx, 14
    mov esi, 0x00FFFFFF
    call draw_rect

    ; Update elapsed MM:SS once per second
    mov eax, r14d
    xor edx, edx
    mov ecx, 15
    div ecx
    cmp eax, [yt_last_sec]
    je .live_skip_sec
    mov [yt_last_sec], eax
    mov rdi, str_yt_timecode
    call fmt_mmss
    mov eax, 370
    mov ebx, 618
    mov ecx, 180
    mov edx, 24
    mov esi, 0x000B0F19
    call draw_rect
    mov dword [text_fg_color], 0x00E2E8F0
    mov byte [cursor_x], 31
    mov byte [cursor_y], 31
    mov rsi, str_yt_timecode
    call print
    call log_ac97_state
.live_skip_sec:

    mov r15d, 45
.live_sync_loop:
    mov ecx, 80000
.live_idle:
    pause
    dec ecx
    jnz .live_idle

    call yt_handle_input
    cmp eax, 1
    je near .video_stream_done
    cmp byte [yt_video_paused], 1
    jne .live_chk_sync

    ; Paused badge + spin until resumed or closed
    mov eax, 176
    mov ebx, 618
    mov ecx, 180
    mov edx, 24
    mov esi, 0x000B0F19
    call draw_rect
    mov dword [text_fg_color], 0x00FACC15
    mov byte [cursor_x], 15
    mov byte [cursor_y], 31
    mov rsi, str_yt_paused_badge
    call print
.live_pause_wait:
    pause
    call yt_handle_input
    cmp eax, 1
    je near .video_stream_done
    cmp byte [yt_video_paused], 1
    je .live_pause_wait
    mov eax, 176
    mov ebx, 618
    mov ecx, 180
    mov edx, 24
    mov esi, 0x000B0F19
    call draw_rect
    mov dword [text_fg_color], 0x0022C55E
    mov byte [cursor_x], 15
    mov byte [cursor_y], 31
    mov rsi, str_yt_playing_badge
    call print
    jmp .live_next_frm

.live_chk_sync:
    call live_topup_audio
    mov ebx, [audio_bm]
    test ebx, ebx
    jz .live_next_frm
    lea edx, [ebx + PO_SR]
    in al, dx
    test al, 1
    jnz .live_next_frm          ; DMA halted (audio ended or unavailable) -> finish remaining frames
    call live_get_abs_civ       ; eax = abs_civ
    mov ecx, eax
    and eax, 31
    movzx esi, word [AUDIO_BDL + rax*8 + 4]
    imul ecx, 48000
    lea edx, [ebx + PO_PICB]
    in ax, dx
    movzx eax, ax
    cmp eax, esi
    jae .live_picb_ok
    sub esi, eax
    add ecx, esi
.live_picb_ok:
    mov eax, ecx
    xor edx, edx
    mov esi, 6400
    div esi
    cmp eax, r14d
    ja .live_jump_frm
    dec r15d
    jnz .live_sync_loop
.live_next_frm:
    inc r14d
    jmp .live_frame_loop
.live_jump_frm:
    mov r14d, eax
    jmp .live_frame_loop

.live_drain_done:
    mov r13d, 30
.live_drain_lp:
    mov ebx, [audio_bm]
    test ebx, ebx
    jz .video_stream_done
    lea edx, [ebx + PO_SR]
    in al, dx
    test al, 1
    jnz .video_stream_done
    call yt_handle_input
    cmp eax, 1
    je .video_stream_done
    mov ecx, 600000
.ld_w:
    pause
    dec ecx
    jnz .ld_w
    dec r13d
    jnz .live_drain_lp
    jmp .video_stream_done

.offline_fallback_select:
    cmp dword [yt_playing_seed], 0
    jne near .fallback_thumb_video

    ; Load real 19s 48kHz 16-bit stereo PCM audio (LBA 10000, 7125 sectors -> 0x00600000)
    mov eax, VIDEO_PCM_LBA
    mov ecx, VIDEO_PCM_SECTORS
    mov rdi, AUDIO_DMA_BUFFER
    call ata_read_sectors
    mov dword [audio_size], VIDEO_PCM_BYTES""", "play_real_video_live_streaming")

# 4. Also stop host UDP stream cleanly in .video_stream_done
src = replace_exact(src, """.video_stream_done:
    mov eax, [audio_bm]
    test eax, eax
    jz .skip_done_dma
    add eax, PO_CR
    mov dx, ax
    mov al, 2
    out dx, al
.skip_done_dma:""", """.video_stream_done:
    cmp byte [net_is_live_vid], 1
    jne .skip_net_stop
    mov byte [net_is_live_vid], 0
    mov al, 5                   ; CMD_STOP_VIDEO
    mov ah, [yt_playing_slot]
    xor ebx, ebx
    xor ecx, ecx
    xor edx, edx
    xor r8d, r8d
    movzx r9d, word [e1000_sess_id]
    call e1000_send_udp_req
.skip_net_stop:
    mov eax, [audio_bm]
    test eax, eax
    jz .skip_done_dma
    add eax, PO_CR
    mov dx, ax
    mov al, 2
    out dx, al
.skip_done_dma:""", "video_stream_done_stop_udp")

# 5. Fix offline 00:19 restore & add e1000 + UDP + audio ring helpers cleanly right after log_ac97_state
src = replace_exact(src, """str_ac97_dbg_prefix: db "AC97 ",0

; ------------------------------------------------------------
; draw_yuv420_320x240_2x:""", """str_ac97_dbg_prefix: db "AC97 ",0

; ============================================================
; INTEL 82540EM (e1000) + UDP MEDIA STREAMING ENGINE (10.0.2.2:8082)
; ============================================================
E1000_RX_DESC   equ 0x03200000
E1000_TX_DESC   equ 0x03201000
E1000_TX_BUF    equ 0x03202000
E1000_PKT_SCR   equ 0x03208000
E1000_RX_BUF    equ 0x03210000

; Format seconds (EAX) as "MM:SS" into 5-byte buffer [RDI]
fmt_mmss:
    push rax
    push rcx
    push rdx
    xor edx, edx
    mov ecx, 60
    div ecx
    cmp eax, 99
    jbe .fm_ok
    mov eax, 99
.fm_ok:
    push rdx
    xor edx, edx
    mov ecx, 10
    div ecx
    add al, '0'
    mov [rdi + 0], al
    add dl, '0'
    mov [rdi + 1], dl
    mov byte [rdi + 2], ':'
    pop rax
    xor edx, edx
    div ecx
    add al, '0'
    mov [rdi + 3], al
    add dl, '0'
    mov [rdi + 4], dl
    pop rdx
    pop rcx
    pop rax
    ret

e1000_init:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    cmp byte [e1000_ready], 1
    je .ei_ok
    mov esi, [pci_nic_bar0]
    test esi, esi
    jz .ei_fail
    mov dword [rsi + 0x00D8], 0xFFFFFFFF    ; IMC
    mov dword [rsi + 0x0000], 0x04000000    ; CTRL RST
    mov ecx, 20000
.ei_rst:
    pause
    dec ecx
    jnz .ei_rst
    mov dword [rsi + 0x0000], 0x00000060    ; CTRL SLU | ASDE

    mov eax, [rsi + 0x5400]
    mov [e1000_our_mac], eax
    mov ax, [rsi + 0x5404]
    mov [e1000_our_mac + 4], ax

    mov rdi, E1000_RX_DESC
    mov eax, E1000_RX_BUF
    mov ecx, 64
.ei_rxd:
    mov [rdi], rax
    mov qword [rdi + 8], 0
    add eax, 2048
    add rdi, 16
    dec ecx
    jnz .ei_rxd

    mov dword [rsi + 0x2800], E1000_RX_DESC
    mov dword [rsi + 0x2804], 0
    mov dword [rsi + 0x2808], 1024
    mov dword [rsi + 0x2810], 0
    mov dword [rsi + 0x2818], 63
    mov dword [rsi + 0x0100], 0x0400801A    ; RCTL EN|UPE|MPE|BAM|SECRC

    mov rdi, E1000_TX_DESC
    xor eax, eax
    mov ecx, 32
    rep stosd
    mov dword [rsi + 0x3800], E1000_TX_DESC
    mov dword [rsi + 0x3804], 0
    mov dword [rsi + 0x3808], 128
    mov dword [rsi + 0x3810], 0
    mov dword [rsi + 0x3818], 0
    mov dword [rsi + 0x0400], 0x000400FA    ; TCTL EN|PSP|CT|COLD
    mov dword [rsi + 0x0410], 0x0060200A    ; TIPG

    mov dword [e1000_rx_cur], 0
    mov dword [e1000_tx_cur], 0
    mov byte [e1000_ready], 1

    ; ARP who-has 10.0.2.2 so NAT caches our MAC & learns gateway MAC
    mov al, 1
    xor esi, esi
    mov edx, 0x0202000A
    call e1000_send_arp
    mov ecx, 200000
.ei_arp_w:
    push rcx
    call e1000_poll_udp
    test eax, eax
    jz .ei_arp_n
    call e1000_rx_release
.ei_arp_n:
    pop rcx
    pause
    dec ecx
    jnz .ei_arp_w
.ei_ok:
    mov eax, 1
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret
.ei_fail:
    xor eax, eax
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; RSI = packet buffer, ECX = byte length
e1000_tx_frame:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    mov eax, [e1000_tx_cur]
    mov ebx, eax
    shl ebx, 11
    add ebx, E1000_TX_BUF
    mov rdi, rbx
    cmp ecx, 60
    jae .etx_len_ok
    push rdi
    push rax
    xor eax, eax
    push rcx
    mov ecx, 15
    rep stosd
    pop rcx
    pop rax
    pop rdi
    mov edx, 60
    jmp .etx_cp
.etx_len_ok:
    mov edx, ecx
.etx_cp:
    rep movsb
    mov ecx, eax
    shl ecx, 4
    add ecx, E1000_TX_DESC
    mov [rcx + 0], rbx
    mov word [rcx + 8], dx
    mov word [rcx + 10], 0x0B00 ; CSO=0, CMD=EOP|IFCS|RS
    mov byte [rcx + 12], 0
    inc eax
    and eax, 7
    mov [e1000_tx_cur], eax
    mov esi, [pci_nic_bar0]
    mov [rsi + 0x3818], eax
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; AL = 1 (req) or 2 (rep), RSI = target MAC ptr (or 0 for ff..ff), EDX = target IP (net order)
e1000_send_arp:
    push rdi
    push rcx
    push rax
    mov rdi, E1000_PKT_SCR
    test rsi, rsi
    jz .esa_bc
    mov eax, [rsi]
    mov [rdi], eax
    mov ax, [rsi + 4]
    mov [rdi + 4], ax
    jmp .esa_src
.esa_bc:
    mov dword [rdi], 0xFFFFFFFF
    mov word [rdi + 4], 0xFFFF
.esa_src:
    mov eax, [e1000_our_mac]
    mov [rdi + 6], eax
    mov ax, [e1000_our_mac + 4]
    mov [rdi + 10], ax
    mov word [rdi + 12], 0x0608 ; ARP
    mov dword [rdi + 14], 0x00080100 ; HTYPE=1, PTYPE=0x0800
    mov word [rdi + 18], 0x0406      ; HLEN=6, PLEN=4
    pop rax
    mov byte [rdi + 20], 0
    mov [rdi + 21], al
    mov eax, [e1000_our_mac]
    mov [rdi + 22], eax
    mov ax, [e1000_our_mac + 4]
    mov [rdi + 26], ax
    mov dword [rdi + 28], 0x0F02000A ; 10.0.2.15
    test rsi, rsi
    jz .esa_tha0
    mov eax, [rsi]
    mov [rdi + 32], eax
    mov ax, [rsi + 4]
    mov [rdi + 36], ax
    jmp .esa_tpa
.esa_tha0:
    mov dword [rdi + 32], 0
    mov word [rdi + 36], 0
.esa_tpa:
    mov [rdi + 38], edx
    mov rsi, E1000_PKT_SCR
    mov ecx, 42
    call e1000_tx_frame
    pop rcx
    pop rdi
    ret

; AL=cmd, AH=slot, EBX=req_id, ECX=item_idx, EDX=byte_off, R8D=max_len, R9D=sess_id
e1000_send_udp_req:
    push rax
    push rcx
    push rdx
    push rsi
    push rdi
    mov rdi, E1000_PKT_SCR
    ; Eth hdr (14)
    push rax
    mov eax, [e1000_gw_mac]
    mov [rdi + 0], eax
    mov ax, [e1000_gw_mac + 4]
    mov [rdi + 4], ax
    mov eax, [e1000_our_mac]
    mov [rdi + 6], eax
    mov ax, [e1000_our_mac + 4]
    mov [rdi + 10], ax
    mov word [rdi + 12], 0x0008 ; IPv4
    ; IPv4 hdr (20)
    mov dword [rdi + 14], 0x30000045 ; ver=4,ihl=5,tos=0,len=48 BE
    mov ax, [e1000_ip_id]
    inc word [e1000_ip_id]
    mov [rdi + 18], ax
    mov dword [rdi + 20], 0x11400000 ; frag=0, ttl=64, proto=17
    mov word [rdi + 24], 0           ; csum placeholder
    mov dword [rdi + 26], 0x0F02000A ; 10.0.2.15
    mov dword [rdi + 30], 0x0202000A ; 10.0.2.2
    ; Compute 10-word IP checksum
    push rcx
    xor eax, eax
    xor ecx, ecx
.ip_ck:
    movzx esi, word [rdi + 14 + rcx*2]
    add eax, esi
    inc ecx
    cmp ecx, 10
    jb .ip_ck
    mov ecx, eax
    shr ecx, 16
    and eax, 0xFFFF
    add eax, ecx
    mov ecx, eax
    shr ecx, 16
    add eax, ecx
    not ax
    mov [rdi + 24], ax
    pop rcx
    ; UDP hdr (8)
    mov dword [rdi + 34], 0x921F50C3 ; src=50000 BE, dst=8082 BE
    mov dword [rdi + 38], 0x00001C00 ; len=28 BE, csum=0
    pop rax
    ; 20-byte 'NV' payload at [rdi + 42]
    mov word [rdi + 42], 0x564E      ; "NV"
    mov [rdi + 44], al               ; cmd
    mov [rdi + 45], ah               ; slot
    mov [rdi + 46], ebx              ; req_id
    mov [rdi + 50], ecx              ; item_idx
    mov [rdi + 54], edx              ; byte_off
    mov [rdi + 58], r8w              ; max_len
    mov [rdi + 60], r9w              ; sess_id
    mov rsi, E1000_PKT_SCR
    mov ecx, 62
    call e1000_tx_frame
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rax
    ret

e1000_rx_release:
    push rax
    push rdx
    push rsi
    mov esi, [pci_nic_bar0]
    mov eax, [e1000_rx_cur]
    mov edx, eax
    shl edx, 4
    add edx, E1000_RX_DESC
    mov byte [rdx + 12], 0
    mov [rsi + 0x2818], eax
    inc eax
    and eax, 63
    mov [e1000_rx_cur], eax
    pop rsi
    pop rdx
    pop rax
    ret

e1000_poll_udp:
    push rbx
    push rdx
.ep_next:
    mov eax, [e1000_rx_cur]
    mov edx, eax
    shl edx, 4
    add edx, E1000_RX_DESC
    test byte [rdx + 12], 0x01
    jz .ep_none
    shl eax, 11
    add eax, E1000_RX_BUF
    mov rbx, rax
    movzx ecx, word [rdx + 8]
    cmp ecx, 42
    jb .ep_drop
    cmp word [rbx + 12], 0x0608
    je .ep_arp
    cmp word [rbx + 12], 0x0008
    jne .ep_drop
    cmp byte [rbx + 23], 17
    jne .ep_drop
    cmp word [rbx + 36], 0x50C3
    jne .ep_drop
    movzx eax, word [rbx + 38]
    xchg al, ah
    sub eax, 8
    jb .ep_drop
    mov ecx, eax
    lea rsi, [rbx + 42]
    mov eax, 1
    pop rdx
    pop rbx
    ret
.ep_arp:
    cmp dword [rbx + 28], 0x0202000A
    jne .ep_arp_req
    mov eax, [rbx + 22]
    mov [e1000_gw_mac], eax
    mov ax, [rbx + 26]
    mov [e1000_gw_mac + 4], ax
.ep_arp_req:
    cmp word [rbx + 20], 0x0100
    jne .ep_drop
    cmp dword [rbx + 38], 0x0F02000A
    jne .ep_drop
    mov al, 2
    lea rsi, [rbx + 22]
    mov edx, [rbx + 28]
    call e1000_send_arp
.ep_drop:
    call e1000_rx_release
    jmp .ep_next
.ep_none:
    xor eax, eax
    pop rdx
    pop rbx
    ret

; Poll CMD_START_VIDEO -> EAX=1 if NS received
net_poll_start_video:
    push rbx
    push rcx
    push rdx
    push rsi
    push r8
    push r9
    inc dword [e1000_req_seq]
    mov ebx, [e1000_req_seq]
    mov al, 2
    mov ah, [yt_playing_slot]
    xor ecx, ecx
    xor edx, edx
    xor r8d, r8d
    movzx r9d, word [e1000_sess_id]
    call e1000_send_udp_req
    mov edx, 2500000
.nps_w:
    call e1000_poll_udp
    test eax, eax
    jz .nps_spin
    cmp ecx, 20
    jb .nps_drop
    cmp word [rsi], 0x534E      ; "NS"
    jne .nps_drop
    cmp [rsi + 4], ebx
    jne .nps_drop
    mov al, [rsi + 2]
    mov [net_start_status], al
    mov eax, [rsi + 8]
    mov [yt_stream_dur], eax
    mov eax, [rsi + 12]
    mov [yt_total_frames], eax
    call e1000_rx_release
    mov eax, 1
    pop r9
    pop r8
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret
.nps_drop:
    call e1000_rx_release
    jmp .nps_w
.nps_spin:
    pause
    dec edx
    jnz .nps_w
    xor eax, eax
    pop r9
    pop r8
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; AL=cmd, AH=slot, ECX=item_idx, EDX=byte_off, R8D=max_len, RDI=dst -> EAX=bytes (or -1 on error)
net_fetch_batch:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push rbp
    push r12
    push r13
    push r14
    push r15

    mov [net_arg_cmd], ax
    mov [net_arg_item], ecx
    mov [net_arg_off], edx
    mov [net_arg_maxlen], r8d
    mov [net_arg_dst], rdi

    mov r14d, 6                 ; max retries
.nfb_retry:
    inc dword [e1000_req_seq]
    mov ebx, [e1000_req_seq]
    mov ax, [net_arg_cmd]
    mov ecx, [net_arg_item]
    mov edx, [net_arg_off]
    mov r8d, [net_arg_maxlen]
    movzx r9d, word [e1000_sess_id]
    call e1000_send_udp_req

    xor r12d, r12d              ; received pkt bitmask (0..31)
    xor r13d, r13d              ; unique packets received
    mov ebp, 0xFFFF             ; expected pkt_count
    mov dword [net_max_end], 0
    mov byte [net_eof_flag], 0
    mov r15d, 4000000

.nfb_poll:
    call e1000_poll_udp
    test eax, eax
    jz .nfb_spin
    cmp ecx, 16
    jb .nfb_drop
    cmp word [rsi], 0x444E      ; "ND"
    jne .nfb_drop
    cmp [rsi + 4], ebx
    jne .nfb_drop

    movzx edx, word [rsi + 12]  ; pkt_count
    test edx, edx
    jnz .nfb_has_pkts
    mov al, [rsi + 2]
    mov [net_eof_flag], al
    call e1000_rx_release
    xor eax, eax
    jmp .nfb_exit

.nfb_has_pkts:
    mov ebp, edx
    movzx eax, byte [rsi + 3]   ; pkt_idx
    cmp eax, 31
    ja .nfb_drop
    bt r12d, eax
    jc .nfb_drop
    bts r12d, eax
    inc r13d
    mov al, [rsi + 2]
    or [net_eof_flag], al

    mov edx, [rsi + 8]          ; rel_off
    movzx ecx, word [rsi + 14]  ; payload_len
    lea eax, [edx + ecx]
    cmp eax, [net_max_end]
    jbe .nfb_no_max
    mov [net_max_end], eax
.nfb_no_max:
    mov rdi, [net_arg_dst]
    add rdi, rdx
    push rsi
    add rsi, 16
    rep movsb
    pop rsi
    call e1000_rx_release

    cmp r13d, ebp
    jb .nfb_poll
    mov eax, [net_max_end]
    jmp .nfb_exit

.nfb_drop:
    call e1000_rx_release
    jmp .nfb_poll
.nfb_spin:
    pause
    dec r15d
    jnz .nfb_poll
    dec r14d
    jnz near .nfb_retry
    mov eax, -1

.nfb_exit:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; Fetch complete 115200B video frame ECX -> RDI; handles eof=2 decoding wait
net_fetch_video_frame:
    push rbx
    push r12
    push r13
    mov r13d, 30                ; decode-wait retries (~1.5s)
.nfv_retry_item:
    xor r12d, r12d              ; byte_off = 0..115200
.nfv_chunk:
    mov edx, 115200
    sub edx, r12d
    cmp edx, 24576
    jbe .nfv_len_ok
    mov edx, 24576
.nfv_len_ok:
    mov r8d, edx
    mov al, 3                   ; CMD_GET_VIDEO_FRAME
    mov ah, [yt_playing_slot]
    mov edx, r12d
    push rdi
    add rdi, r12
    call net_fetch_batch
    pop rdi
    cmp eax, -1
    je .nfv_fail
    test eax, eax
    jz .nfv_empty
    add r12d, eax
    cmp r12d, 115200
    jb .nfv_chunk
    mov eax, r12d
    pop r13
    pop r12
    pop rbx
    ret
.nfv_empty:
    cmp byte [net_eof_flag], 1
    je .nfv_fail
    ; eof == 2 (still decoding): brief pause then retry
    push rcx
    mov ecx, 1500000
.nfv_w:
    pause
    dec ecx
    jnz .nfv_w
    pop rcx
    dec r13d
    jnz .nfv_retry_item
.nfv_fail:
    xor eax, eax
    pop r13
    pop r12
    pop rbx
    ret

; Fetch 0.5s audio segment ECX (up to 96000B) -> RDI; returns EAX=actual bytes
net_fetch_audio_seg:
    push rbx
    push r12
    push r13
    mov r13d, 30
.nfa_retry_item:
    xor r12d, r12d
.nfa_chunk:
    mov edx, 96000
    sub edx, r12d
    cmp edx, 24576
    jbe .nfa_len_ok
    mov edx, 24576
.nfa_len_ok:
    mov r8d, edx
    mov al, 4                   ; CMD_GET_AUDIO_SEG
    mov ah, [yt_playing_slot]
    mov edx, r12d
    push rdi
    add rdi, r12
    call net_fetch_batch
    pop rdi
    cmp eax, -1
    je .nfa_fail
    test eax, eax
    jz .nfa_empty
    add r12d, eax
    cmp byte [net_eof_flag], 1
    je .nfa_done
    cmp r12d, 96000
    jb .nfa_chunk
.nfa_done:
    mov eax, r12d
    pop r13
    pop r12
    pop rbx
    ret
.nfa_empty:
    cmp byte [net_eof_flag], 1
    je .nfa_done
    push rcx
    mov ecx, 1500000
.nfa_w:
    pause
    dec ecx
    jnz .nfa_w
    pop rcx
    dec r13d
    jnz .nfa_retry_item
.nfa_fail:
    xor eax, eax
    pop r13
    pop r12
    pop rbx
    ret

; Returns EAX = monotonic segment index (wraps*32 + PO_CIV)
live_get_abs_civ:
    push rbx
    push rcx
    push rdx
    mov ebx, [audio_bm]
    test ebx, ebx
    jz .lgc_0
    lea edx, [ebx + PO_CIV]
    in al, dx
    movzx eax, al
    and eax, 31
    mov ecx, [aud_civ_prev]
    cmp eax, ecx
    jae .lgc_nowrap
    sub ecx, eax
    cmp ecx, 16
    jbe .lgc_nowrap
    inc dword [aud_wraps]
.lgc_nowrap:
    mov [aud_civ_prev], eax
    mov ecx, [aud_wraps]
    shl ecx, 5
    or eax, ecx
    pop rdx
    pop rcx
    pop rbx
    ret
.lgc_0:
    xor eax, eax
    pop rdx
    pop rcx
    pop rbx
    ret

; Top up AC97 32-entry ring up to abs_civ + 6 segments (3.0s read-ahead)
live_topup_audio:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
.lta_loop:
    cmp byte [aud_eof_flag], 1
    je .lta_done
    call live_get_abs_civ
    add eax, 6
    mov ecx, [aud_next_seg]
    cmp ecx, eax
    jae .lta_done
    mov ebx, ecx
    and ebx, 31
    mov eax, ebx
    imul eax, 96000
    add eax, AUDIO_DMA_BUFFER
    mov rdi, rax
    push rcx
    push rbx
    call net_fetch_audio_seg
    pop rbx
    pop rcx
    test eax, eax
    jle .lta_eof_only
    mov edx, ebx
    imul edx, 96000
    add edx, AUDIO_DMA_BUFFER
    mov edi, ebx
    shl edi, 3
    add edi, AUDIO_BDL
    mov [edi + 0], edx
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
    out dx, al
.lta_chk_eof:
    cmp byte [net_eof_flag], 1
    jne .lta_loop
.lta_eof_only:
    mov byte [aud_eof_flag], 1
.lta_done:
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ------------------------------------------------------------
; draw_yuv420_320x240_2x:""", "e1000_and_streaming_engine")

# 6. Restore offline 00:19 timecode cleanly before HD offline loop
src = replace_exact(src, """    ; Load real 19s 48kHz 16-bit stereo PCM audio (LBA 10000, 7125 sectors -> 0x00600000)
    mov eax, VIDEO_PCM_LBA
    mov ecx, VIDEO_PCM_SECTORS
    mov rdi, AUDIO_DMA_BUFFER
    call ata_read_sectors
    mov dword [audio_size], VIDEO_PCM_BYTES""", """    ; Offline Video 1 (Me at the zoo): set "00:00 / 00:19" timecode & load LBA 10000 PCM
    mov dword [str_yt_timecode + 8], 0x31303A30
    mov byte [str_yt_timecode + 12], '9'
    mov eax, VIDEO_PCM_LBA
    mov ecx, VIDEO_PCM_SECTORS
    mov rdi, AUDIO_DMA_BUFFER
    call ata_read_sectors
    mov dword [audio_size], VIDEO_PCM_BYTES""", "offline_restore_0019")

# 7. Remove stale hardcoded duration badge overlays in Chrome YouTube cards
src = replace_exact(src, """    ; Video 1 Thumbnail (80x45 at X=52, Y=214)
    mov rsi, [yt_thumb_ptr_0]
    mov eax, 52
    mov ebx, 214
    mov ecx, 80
    mov edx, 45
    call draw_raw_image_32bpp

    ; Duration badge 1 (0:19)
    mov eax, 96
    mov ebx, 244
    mov ecx, 34
    mov edx, 14
    mov esi, 0x00000000
    call draw_rect
    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 13
    mov byte [cursor_y], 12
    mov rsi, str_yt_dur_0
    call print

    ; Video 2 Thumbnail (80x45 at X=52, Y=274)
    mov rsi, [yt_thumb_ptr_1]
    mov eax, 52
    mov ebx, 274
    mov ecx, 80
    mov edx, 45
    call draw_raw_image_32bpp

    ; Duration badge 2 (3:33)
    mov eax, 96
    mov ebx, 304
    mov ecx, 34
    mov edx, 14
    mov esi, 0x00000000
    call draw_rect
    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 13
    mov byte [cursor_y], 15
    mov rsi, str_yt_dur_1
    call print

    ; Video 3 Thumbnail (80x45 at X=52, Y=334)
    mov rsi, [yt_thumb_ptr_2]
    mov eax, 52
    mov ebx, 334
    mov ecx, 80
    mov edx, 45
    call draw_raw_image_32bpp

    ; Duration badge 3 (10:35)
    mov eax, 90
    mov ebx, 364
    mov ecx, 40
    mov edx, 14
    mov esi, 0x00000000
    call draw_rect
    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 12
    mov byte [cursor_y], 18
    mov rsi, str_yt_dur_2
    call print""", """    ; Video 1 Thumbnail (80x45 at X=52, Y=214)
    mov rsi, [yt_thumb_ptr_0]
    mov eax, 52
    mov ebx, 214
    mov ecx, 80
    mov edx, 45
    call draw_raw_image_32bpp

    ; Video 2 Thumbnail (80x45 at X=52, Y=274)
    mov rsi, [yt_thumb_ptr_1]
    mov eax, 52
    mov ebx, 274
    mov ecx, 80
    mov edx, 45
    call draw_raw_image_32bpp

    ; Video 3 Thumbnail (80x45 at X=52, Y=334)
    mov rsi, [yt_thumb_ptr_2]
    mov eax, 52
    mov ebx, 334
    mov ecx, 80
    mov edx, 45
    call draw_raw_image_32bpp""", "chrome_clean_thumbnails")

# 8. Fix .yt_loop typing bug (don't steal 'v'/'p' or non-empty '1'/'2'/'3' from search box)
src = replace_exact(src, """    ; Mode 0: Search Bar typing & Video Playback shortcuts ([ = Video 1, ] = Video 2, \\ = Video 3)!
    cmp eax, '1'
    je .yt_play_v1
    cmp eax, '2'
    je .yt_play_v2
    cmp eax, '3'
    je .yt_play_v3
    cmp eax, 'v'
    je .yt_play_v1
    cmp eax, 'V'
    je .yt_play_v1
    cmp eax, 'p'
    je .yt_play_v1
    cmp eax, 'P'
    je .yt_play_v1
    cmp eax, '['
    je .yt_play_v1
    cmp eax, ']'
    je .yt_play_v2
    cmp eax, '\\'
    je .yt_play_v3""", """    ; Mode 0: Search Bar typing & shortcuts ([ ] \\ always; 1 2 3 only when search bar empty)
    cmp eax, '['
    je .yt_play_v1
    cmp eax, ']'
    je .yt_play_v2
    cmp eax, '\\'
    je .yt_play_v3
    cmp byte [yt_search_len], 0
    jne .yt_type_char
    cmp eax, '1'
    je .yt_play_v1
    cmp eax, '2'
    je .yt_play_v2
    cmp eax, '3'
    je .yt_play_v3
.yt_type_char:""", "yt_loop_fix_search_typing")

# 9. Add new streaming state vars & trim verbose padding strings to fit well under 65536 bytes
src = replace_exact(src, """str_exp_modal_docs:
    db "==================================================",13,10
    db "  Folder: C:\\NovaOS\\Documents",13,10
    db "==================================================",13,10
    db "  [TXT]  project_notes.txt     (1,248 bytes)",13,10
    db "  [LOG]  hardware_pci.log      (4,096 bytes)",13,10
    db "  [CFG]  network_eth0.cfg        (256 bytes)",13,10,13,10
    db "  Status: 3 files, 0 folders",13,10
    db "  Press any key to return to File Explorer...",0

str_exp_modal_downloads:
    db "==================================================",13,10
    db "  Folder: C:\\NovaOS\\Downloads",13,10
    db "==================================================",13,10
    db "  [ZIP]  Nova-Os-main.zip      (4,821,040 bytes)",13,10
    db "         Source: https://github.com/aidaninvents",13,10
    db "  [NOSP] patch_kernel.nosp         (1,024 bytes)",13,10,13,10
    db "  Status: Verified GitHub release archive ready",13,10
    db "  Press any key to return to File Explorer...",0

str_exp_modal_fonts:
    db "==================================================",13,10
    db "  Folder: C:\\NovaOS\\Fonts",13,10
    db "==================================================",13,10
    db "  [FNT]  segoe.fnt             (12x20 Proportional)",13,10
    db "  [PNG]  charsheet_12x20.png   (Bitmap Atlas)",13,10
    db "  [PNG]  charsheet_12x30.png   (HD Glyphs)",13,10,13,10
    db "  Press any key to return to File Explorer...",0

str_exp_modal_system:
    db "==================================================",13,10
    db "  Folder: C:\\NovaOS\\System",13,10
    db "==================================================",13,10
    db "  [SYS]  kernel.bin    (NovaOS 64-bit Long Mode)",13,10
    db "  [SYS]  e1000.sys     (Intel 82540EM Ethernet)",13,10
    db "  [SYS]  ps2mouse.sys  (PS/2 Auxiliary Engine)",13,10
    db "  [SYS]  novafs.sys    (Storage File System)",13,10,13,10
    db "  Press any key to return to File Explorer...",0

str_exp_modal_readme:
    db "==================================================",13,10
    db "  File Viewer: readme.txt",13,10
    db "==================================================",13,10
    db "  NovaOS 1.02.0000 26Q4 Build 26110.0100",13,10
    db "  Created by Aidan Gaber (aidaninvents)",13,10
    db "  GitHub: https://github.com/aidaninvents/Nova-Os ",13,10,13,10
    db "  Key Features:",13,10
    db "  - Full Intel 82540EM Gigabit Ethernet & WiFi",13,10
    db "  - PS/2 Hardware Mouse Pointer & Tracking",13,10
    db "  - Interactive Double-Tap File Explorer",13,10
    db "  - Decoded Chrome DOM, YouTube, Java & HTML5",13,10,13,10
    db "  Press any key to return to File Explorer...",0

str_exp_modal_notes:
    db "==================================================",13,10
    db "  File Viewer: notes.txt",13,10
    db "==================================================",13,10
    db "  * WiFi / Ethernet: type 'run wifi.nosp'",13,10
    db "    Select [1] for VirtualBox Intel 82540EM.",13,10
    db "  * Web Browser: type 'open browser.nosp'",13,10
    db "    Browse GitHub repo, play video, or download.",13,10
    db "  * Double-tap any file in Explorer to open it!",13,10,13,10
    db "  Press any key to return to File Explorer...",0

str_exp_modal_audio:
    db "==================================================",13,10
    db "  Audio Player: startup.wav",13,10
    db "==================================================",13,10
    db "  [PLAYING] C major chime chord (523Hz -> 1047Hz) ",13,10
    db "  Output: AC97 / PC Speaker Synthesizer",13,10
    db "  Status: Playback completed!",13,10,13,10
    db "  Press any key to return to File Explorer...",0

str_exp_modal_font_preview:
    db "==================================================",13,10
    db "  Font Viewer: segoe.fnt",13,10
    db "==================================================",13,10
    db "  ABCDEFGHIJKLMNOPQRSTUVWXYZ",13,10
    db "  abcdefghijklmnopqrstuvwxyz",13,10
    db "  0123456789  !@#$%^&*()_+-=[]{}|;:<>?,./",13,10
    db "  Encoding: 12x20 Anti-Aliased Linear Raster Glyph",13,10,13,10
    db "  Press any key to return to File Explorer...",0""", """str_exp_modal_docs:
    db "C:\\NovaOS\\Documents",13,10,"  project_notes.txt, hardware_pci.log",13,10,"Press any key...",0
str_exp_modal_downloads:
    db "C:\\NovaOS\\Downloads",13,10,"  Nova-Os-main.zip, patch_kernel.nosp",13,10,"Press any key...",0
str_exp_modal_fonts:
    db "C:\\NovaOS\\Fonts",13,10,"  segoe.fnt, charsheet_12x20/30.png",13,10,"Press any key...",0
str_exp_modal_system:
    db "C:\\NovaOS\\System",13,10,"  kernel.bin, e1000.sys, novafs.sys",13,10,"Press any key...",0
str_exp_modal_readme:
    db "readme.txt: NovaOS 1.02.0000 by Aidan Gaber",13,10,"  e1000 Net, Mouse, YouTube",13,10,"Press any key...",0
str_exp_modal_notes:
    db "notes.txt: wifi->[1] e1000, browser, youtube",13,10,"Press any key...",0
str_exp_modal_audio:
    db "startup.wav: AC97 Stereo Chime (Done)",13,10,"Press any key...",0
str_exp_modal_font_preview:
    db "segoe.fnt (12x20):",13,10,"  ABCDEFGHIJKLMNOPQRSTUVWXYZ",13,10,"  abcdefghijklmnopqrstuvwxyz",13,10,"Press any key...",0""", "trim_exp_modal_strings")

src = replace_exact(src, """str_bridge_yt_feed:      db "YT_FEED ",0""", """str_bridge_yt_feed:      db "YT_FEED ",0
str_bridge_yt_thumb:     db "YT_THUMB "
str_bridge_yt_thumb_idx: db "0",10,0
str_yt_connecting:       db "Connecting to YouTube Stream...",0

align 4
e1000_our_mac:   db 0,0,0,0,0,0
e1000_gw_mac:    db 0x52,0x55,0x0A,0x00,0x02,0x02
e1000_ip_id:     dw 1
e1000_sess_id:   dw 1
e1000_rx_cur:    dd 0
e1000_tx_cur:    dd 0
e1000_req_seq:   dd 1
net_max_end:     dd 0
yt_stream_dur:   dd 19
yt_total_frames: dd 284
aud_wraps:       dd 0
aud_civ_prev:    dd 0
aud_next_seg:    dd 0
net_arg_item:    dd 0
net_arg_off:     dd 0
net_arg_maxlen:  dd 0
net_arg_dst:     dq 0
net_arg_cmd:     dw 0
e1000_ready:     db 0
net_eof_flag:    db 0
net_is_live_vid: db 0
net_start_status: db 0
yt_playing_slot: db 0
aud_eof_flag:    db 0""", "add_e1000_stream_vars")

src = replace_exact(src, """str_fallback_youtube:
    db "URL: https://www.youtube.com  [TLS 1.3 | TLS_AES_256_GCM_SHA384]",13,10
    db "     TITLE: YouTube (www.youtube.com - Real Live Video Feed)",13,10
    db "     -----------------------------------------",13,10
    db "               [VIDEO 1] Me at the zoo (https://youtu.be/jNQXAC9IVRw)",13,10
    db "                         Channel: @jawed      | 348M views | 0:19  | 60fps",13,10,13,10
    db "               [VIDEO 2] Rick Astley - Never Gonna Give You Up",13,10
    db "                         Channel: @RickAstley | 1.6B views | 3:33  | 60fps",13,10,13,10
    db "               [VIDEO 3] Big Buck Bunny 60fps 4K - Blender Open Movie",13,10
    db "                         Channel: @Blender    | 24M views  | 10:34 | 60fps",13,10
    db "     -----------------------------------------",13,10
    db "     -> Click ANY Video Thumbnail above or [ > Play Video ] to Watch!",0

str_fallback_wiki:
    db "URL: https://en.wikipedia.org/wiki/Operating_system  [TLS 1.3 SECURE]",13,10
    db "     TITLE: Operating system - Wikipedia",13,10
    db "     -----------------------------------------",13,10
    db "     An operating system (OS) is system software that",13,10
    db "     manages computer hardware and software resources,",13,10
    db "     and provides common services for computer programs.",13,10
    db "     Time-sharing operating systems schedule tasks for",13,10
    db "     efficient use of the system and hardware drivers.",13,10
    db "     -----------------------------------------",13,10
    db "     [Link 1] Operating System  |  [Link 2] x86-64 Arch",13,10
    db "     [Link 3] Computer Kernel   (Click buttons below)",0

str_chrome_search_results:
    db "URL: https://novaos.org/download  [TLS 1.3 | TLS_AES_256_GCM_SHA384]",13,10
    db "     TITLE: NovaOS Official Download Center (https://novaos.org)",13,10
    db "     -----------------------------------------",13,10
    db "     Current Server Ver: NovaOS 1.01 26Q4 (Build 26110.0002)",13,10
    db "     Local Kernel Build: NovaOS 1.02.0000 (Active Release)",13,10
    db "     Included Drivers  : Intel PRO/1000 Ethernet, PS/2 Mouse",13,10
    db "     Security          : TLS 1.3 (TLS_AES_256_GCM_SHA384)",13,10
    db "     -----------------------------------------",13,10
    db "     Status: Up to date! NovaOS 1.02.0000 is active with   ",13,10
    db "     Universal NovaFS Media and 60fps Cinema Engine",0

str_chrome_download_banner:
    db "==================================================",13,10
    db "  Chrome Download: aidaninvents/Nova-Os           ",13,10
    db "==================================================",13,10
    db "  URL: https://github.com/aidaninvents/Nova-Os/... ",13,10
    db "  File: Nova-Os-main.zip (4.82 MB)                ",13,10
    db "  Progress: [================================] 100%",13,10
    db "  Destination: C:\\Downloads\\Nova-Os-main.zip      ",13,10
    db "  Status: Download complete and verified!         ",13,10,13,10
    db "  Press any key to return to Google Chrome...     ",0""", """str_fallback_youtube:
    db "URL: https://www.youtube.com [TLS 1.3]",13,10
    db "  [1] Me at the zoo (0:19)",13,10
    db "  [2] Rick Astley (3:33) | [3] Big Buck Bunny (10:35)",0

str_fallback_wiki:
    db "URL: https://en.wikipedia.org/wiki/Operating_system",13,10
    db "  Operating system hardware/software manager.",0

str_chrome_search_results:
    db "URL: https://novaos.org/download [TLS 1.3]",13,10
    db "  NovaOS 1.02.0000 Active",0

str_chrome_download_banner:
    db "Chrome Download: aidaninvents/Nova-Os -> C:\\Downloads (100%)",13,10,"Press any key...",0""", "trim_fallback_banners")

with open(KERNEL_PATH, "wb") as f:
    f.write(src.replace("\n", newline).encode("utf-8"))
print("Updated kernel.asm cleanly!")
