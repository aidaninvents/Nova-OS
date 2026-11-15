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

# 1. Probe PCI NIC at boot & auto-init e1000 + net_connected
src = replace_exact(src, """    call detect_hardware

    ; ------------------------------------------------------------
    ; Draw boot screen.
    ; ------------------------------------------------------------

    call boot_screen
    call mouse_init
    call audio_init
    call startup_audio
    ; ------------------------------------------------------------
    ; Clear boot screen and show banner before entering shell.
    ; ------------------------------------------------------------

    call clear_screen

    ; Check if network driver was previously saved to NovaFS superblock
    mov byte [net_connected], 0
    cmp dword [NOVAFS + 28], 0x4E455431
    jne .fresh_offline_boot
    mov byte [net_connected], 1
.fresh_offline_boot:""", """    call detect_hardware
    call probe_pci_nic

    ; ------------------------------------------------------------
    ; Draw boot screen.
    ; ------------------------------------------------------------

    call boot_screen
    call mouse_init
    call audio_init
    call startup_audio
    ; ------------------------------------------------------------
    ; Clear boot screen and show banner before entering shell.
    ; ------------------------------------------------------------

    call clear_screen

    ; Auto-initialize Intel 82540EM (e1000) NIC & mark online if present
    mov byte [net_connected], 0
    cmp dword [pci_nic_id], 0xFFFFFFFF
    je .chk_nv_net
    call e1000_init
    test eax, eax
    jz .chk_nv_net
    mov byte [net_connected], 1
    jmp .fresh_offline_boot
.chk_nv_net:
    cmp dword [NOVAFS + 28], 0x4E455431
    jne .fresh_offline_boot
    mov byte [net_connected], 1
.fresh_offline_boot:""", "boot_probe_pci_nic_and_e1000")

# 2. Increase Chrome & YouTube COM1 receive timeouts so HTTPS fetches never cut short
src = replace_exact(src, """    xor r14d, r14d
    mov ecx, 200000           ; Fast non-blocking timeout for live HTTPS internet response""", """    xor r14d, r14d
    mov ecx, 4000000          ; Wait up to ~4s for live HTTPS internet response""", "flw_timeout_init")

src = replace_exact(src, """    mov [rdi + r14], al
    inc r14d
    mov ecx, 50000          ; Inter-byte timeout once streaming starts""", """    mov [rdi + r14], al
    inc r14d
    mov ecx, 400000         ; Inter-byte timeout once streaming starts""", "flw_timeout_cont")

src = replace_exact(src, """    lea rdi, [str_yt_v1_title]
    xor r14d, r14d
    mov ecx, 200000
.yt_rx_loop:""", """    lea rdi, [str_yt_v1_title]
    xor r14d, r14d
    mov ecx, 4000000
.yt_rx_loop:""", "yt_feed_timeout_init")

src = replace_exact(src, """    mov [rdi + r14], al
    inc r14d
    mov ecx, 50000
    jmp .yt_rx_loop""", """    mov [rdi + r14], al
    inc r14d
    mov ecx, 400000
    jmp .yt_rx_loop""", "yt_feed_timeout_cont")

# 3. Clean termination on fetch_com1_thumb fallback
src = replace_exact(src, """    xor r14d, r14d
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
    jmp .fct_lp""", """    xor r14d, r14d
    mov ecx, 2000000
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
    jae .fct_done
    mov [rdi + r14], al
    inc r14d
    mov ecx, 400000
    jmp .fct_lp""", "fetch_com1_thumb_clean")

# 4. In e1000_init: fallback call probe_pci_nic if BAR0 is 0 & don't trigger CTRL RST link-down delay
src = replace_exact(src, """    mov esi, [pci_nic_bar0]
    test esi, esi
    jz .ei_fail
    mov dword [rsi + 0x00D8], 0xFFFFFFFF    ; IMC
    mov dword [rsi + 0x0000], 0x04000000    ; CTRL RST
    mov ecx, 20000
.ei_rst:
    pause
    dec ecx
    jnz .ei_rst
    mov dword [rsi + 0x0000], 0x00000060    ; CTRL SLU | ASDE""", """    mov esi, [pci_nic_bar0]
    test esi, esi
    jnz .ei_have_bar
    call probe_pci_nic
    mov esi, [pci_nic_bar0]
    test esi, esi
    jz near .ei_fail
.ei_have_bar:
    mov dword [rsi + 0x00D8], 0xFFFFFFFF    ; IMC
    mov dword [rsi + 0x0100], 0             ; RCTL off
    mov dword [rsi + 0x0400], 0             ; TCTL off
    mov eax, [rsi + 0x0000]
    or eax, 0x00000060                      ; CTRL SLU | ASDE (preserve PHY timer)
    and eax, 0xFBFFFFF7
    mov [rsi + 0x0000], eax""", "e1000_init_preserve_link")

with open(KERNEL_PATH, "wb") as f:
    f.write(src.replace("\n", newline).encode("utf-8"))
print("Applied boot probe & timeout fixes cleanly!")
