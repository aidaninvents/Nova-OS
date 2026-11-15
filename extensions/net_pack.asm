; ==============================================================================
; NovaOS Extension Module 1: Hardware Driver Extension Pack
; Target: NASM x86-64 (Long Mode) - ELF64 / Flat Binary Compatible
; Architecture: 10 Ethernet Controllers + 40 Modern Wi-Fi Controllers (2020+)
; Integrates directly with NovaOS pci_nic_bar0 and web_response_buf (TLS 1.3)
; ==============================================================================

[BITS 64]
default rel

; ------------------------------------------------------------------------------
; Public Interface
; ------------------------------------------------------------------------------
global net_pack_probe_all
global net_pack_init_ring_descriptors
global net_pack_route_to_tls13
global net_pack_get_device_info
global g_net_pack_active_dev
global g_net_pack_active_type
global g_net_pack_bar0

; ------------------------------------------------------------------------------
; External Kernel Symbols (NovaOS kernel.asm)
; ------------------------------------------------------------------------------
extern pci_nic_bar0
extern pci_nic_id
extern web_response_buf

; ------------------------------------------------------------------------------
; Device Type Classifications
; ------------------------------------------------------------------------------
DEV_TYPE_UNKNOWN        equ 0
; Ethernet
DEV_TYPE_ETH_I225       equ 1       ; Intel I225-V 2.5GbE
DEV_TYPE_ETH_I226       equ 2       ; Intel I226-V 2.5GbE
DEV_TYPE_ETH_RTL8125    equ 3       ; Realtek RTL8125/8126 2.5G/5G
DEV_TYPE_ETH_E1000E     equ 4       ; Intel 82540EM / I211-AT Gigabit
DEV_TYPE_ETH_BCM57      equ 5       ; Broadcom NetXtreme Gigabit
; Wi-Fi
DEV_TYPE_WIFI_AX200     equ 10      ; Intel Wi-Fi 6 AX200
DEV_TYPE_WIFI_AX210     equ 11      ; Intel Wi-Fi 6E AX210
DEV_TYPE_WIFI_AX211     equ 12      ; Intel Wi-Fi 6E AX211 CNVi
DEV_TYPE_WIFI_BE200     equ 13      ; Intel Wi-Fi 7 BE200
DEV_TYPE_WIFI_BE202     equ 14      ; Intel Wi-Fi 7 BE202
DEV_TYPE_WIFI_MT7921    equ 20      ; MediaTek MT7921 802.11ax
DEV_TYPE_WIFI_MT7922    equ 21      ; MediaTek MT7922 (AMD RZ616)
DEV_TYPE_WIFI_MT7925    equ 22      ; MediaTek Wi-Fi 7 MT7925
DEV_TYPE_WIFI_RTL8822   equ 30      ; Realtek RTL8822CE
DEV_TYPE_WIFI_RTL8852   equ 31      ; Realtek RTL8852AE/BE/CE Wi-Fi 6/6E
DEV_TYPE_WIFI_QCNFA     equ 40      ; Qualcomm FastConnect 6800/6900/7800

; ------------------------------------------------------------------------------
; Constants & Structures
; ------------------------------------------------------------------------------
NUM_RX_DESCRIPTORS      equ 128
NUM_TX_DESCRIPTORS      equ 64
PACKET_MAX_LEN          equ 2048

struc NetHwDesc
    .buf_addr_low:      resd 1
    .buf_addr_high:     resd 1
    .length:            resw 1
    .checksum:          resw 1
    .status:            resb 1
    .errors:            resb 1
    .special:           resw 1
endstruc

section .data align=16

g_net_pack_active_dev:  dd 0
g_net_pack_active_type: dd DEV_TYPE_UNKNOWN
g_net_pack_bar0:        dq 0

; ------------------------------------------------------------------------------
; TABLE 1: 10 Modern Ethernet Controllers
; Structure: ((DeviceID << 16) | VendorID), DeviceType (32)
; ------------------------------------------------------------------------------
align 8
g_table_ethernet_10:
    dd 0x15F38086, DEV_TYPE_ETH_I225     ; 1. Intel I225-V 2.5GbE Desktop
    dd 0x15F28086, DEV_TYPE_ETH_I225     ; 2. Intel I225-LM 2.5GbE Enterprise
    dd 0x125B8086, DEV_TYPE_ETH_I226     ; 3. Intel I226-V 2.5GbE
    dd 0x125C8086, DEV_TYPE_ETH_I226     ; 4. Intel I226-LM 2.5GbE
    dd 0x812510EC, DEV_TYPE_ETH_RTL8125  ; 5. Realtek RTL8125 2.5GbE
    dd 0x300010EC, DEV_TYPE_ETH_RTL8125  ; 6. Realtek RTL8125B Gaming 2.5G
    dd 0x812610EC, DEV_TYPE_ETH_RTL8125  ; 7. Realtek RTL8126 5GbE
    dd 0x100E8086, DEV_TYPE_ETH_E1000E   ; 8. Intel 82540EM Gigabit (VBox)
    dd 0x15398086, DEV_TYPE_ETH_E1000E   ; 9. Intel I211-AT Gigabit PCIe
    dd 0x165F14E4, DEV_TYPE_ETH_BCM57    ; 10. Broadcom NetXtreme BCM5720
ETH_TABLE_ENTRIES       equ ($ - g_table_ethernet_10) / 8

; ------------------------------------------------------------------------------
; TABLE 2: 40 Modern Wi-Fi Controllers (2020–Present)
; Structure: ((DeviceID << 16) | VendorID), DeviceType (32)
; ------------------------------------------------------------------------------
align 8
g_table_wifi_40:
    ; Intel Wi-Fi 6 / 6E / 7
    dd 0x27238086, DEV_TYPE_WIFI_AX200   ; 1. Intel Wi-Fi 6 AX200
    dd 0x27258086, DEV_TYPE_WIFI_AX210   ; 2. Intel Wi-Fi 6E AX210
    dd 0x7A708086, DEV_TYPE_WIFI_AX211   ; 3. Intel Wi-Fi 6E AX211 (CNVi)
    dd 0x51F08086, DEV_TYPE_WIFI_AX211   ; 4. Intel Alder Lake-P CNVi
    dd 0x54F08086, DEV_TYPE_WIFI_AX211   ; 5. Intel Raptor Lake CNVi
    dd 0x272B8086, DEV_TYPE_WIFI_BE200   ; 6. Intel Wi-Fi 7 BE200 (320MHz)
    dd 0x272C8086, DEV_TYPE_WIFI_BE202   ; 7. Intel Wi-Fi 7 BE202
    dd 0x7E408086, DEV_TYPE_WIFI_BE200   ; 8. Intel Meteor Lake Wi-Fi 7
    dd 0xA7708086, DEV_TYPE_WIFI_AX210   ; 9. Intel Killer AX1675x
    dd 0x31658086, DEV_TYPE_WIFI_AX200   ; 10. Intel Dual Band AC 3165
    dd 0x24F38086, DEV_TYPE_WIFI_AX200   ; 11. Intel Wireless-AC 8260
    dd 0x24FD8086, DEV_TYPE_WIFI_AX200   ; 12. Intel Wireless-AC 8265
    dd 0x9DF08086, DEV_TYPE_WIFI_AX200   ; 13. Intel Wireless-AC 9560
    dd 0x4DF08086, DEV_TYPE_WIFI_AX200   ; 14. Intel Wi-Fi 6 AX201
    dd 0x43F08086, DEV_TYPE_WIFI_AX200   ; 15. Intel Tiger Lake CNVi
    ; MediaTek Filogic Series
    dd 0x796114C3, DEV_TYPE_WIFI_MT7921  ; 16. MediaTek MT7921 PCIe
    dd 0x792214C3, DEV_TYPE_WIFI_MT7922  ; 17. MediaTek MT7922 6E
    dd 0x790214C3, DEV_TYPE_WIFI_MT7921  ; 18. MediaTek MT7902
    dd 0x060814C3, DEV_TYPE_WIFI_MT7921  ; 19. AMD RZ608 (MT7921K)
    dd 0x061614C3, DEV_TYPE_WIFI_MT7922  ; 20. AMD RZ616 (MT7922A)
    dd 0x792514C3, DEV_TYPE_WIFI_MT7925  ; 21. MediaTek Wi-Fi 7 MT7925
    ; Realtek RTL8822 / RTL8852 Series
    dd 0xC82210EC, DEV_TYPE_WIFI_RTL8822 ; 22. Realtek RTL8822CE
    dd 0x882210EC, DEV_TYPE_WIFI_RTL8822 ; 23. Realtek RTL8822BE
    dd 0xC82110EC, DEV_TYPE_WIFI_RTL8822 ; 24. Realtek RTL8821CE
    dd 0x885210EC, DEV_TYPE_WIFI_RTL8852 ; 25. Realtek RTL8852AE Wi-Fi 6
    dd 0xB85210EC, DEV_TYPE_WIFI_RTL8852 ; 26. Realtek RTL8852BE
    dd 0xC85210EC, DEV_TYPE_WIFI_RTL8852 ; 27. Realtek RTL8852CE Wi-Fi 6E
    dd 0xD72310EC, DEV_TYPE_WIFI_RTL8822 ; 28. Realtek RTL8723DE
    dd 0x818810EC, DEV_TYPE_WIFI_RTL8822 ; 29. Realtek RTL8188EE
    dd 0x876110EC, DEV_TYPE_WIFI_RTL8822 ; 30. Realtek RTL8761BU
    ; Qualcomm FastConnect / Atheros Series
    dd 0x110117CB, DEV_TYPE_WIFI_QCNFA   ; 31. Qualcomm FastConnect 6800
    dd 0x110217CB, DEV_TYPE_WIFI_QCNFA   ; 32. Qualcomm FastConnect 6900
    dd 0x110717CB, DEV_TYPE_WIFI_QCNFA   ; 33. Qualcomm FastConnect 7800 (Wi-Fi 7)
    dd 0x003E168C, DEV_TYPE_WIFI_QCNFA   ; 34. Qualcomm Atheros QCA6174
    dd 0x0042168C, DEV_TYPE_WIFI_QCNFA   ; 35. Qualcomm Atheros QCA9377
    dd 0x1102168C, DEV_TYPE_WIFI_QCNFA   ; 36. Qualcomm QCNFA765
    dd 0x0034168C, DEV_TYPE_WIFI_QCNFA   ; 37. Qualcomm Atheros AR9462
    dd 0x0032168C, DEV_TYPE_WIFI_QCNFA   ; 38. Qualcomm Atheros AR9485
    ; Broadcom BCM Series
    dd 0x43BA14E4, DEV_TYPE_WIFI_QCNFA   ; 39. Broadcom BCM43602 802.11ac
    dd 0x43E914E4, DEV_TYPE_WIFI_QCNFA   ; 40. Broadcom BCM4364
WIFI_TABLE_ENTRIES      equ ($ - g_table_wifi_40) / 8

section .bss align=4096
net_pack_rx_ring:       resb (NUM_RX_DESCRIPTORS * 16)
net_pack_tx_ring:       resb (NUM_TX_DESCRIPTORS * 16)
net_pack_packet_pool:   resb (NUM_RX_DESCRIPTORS * PACKET_MAX_LEN)

section .text

; ------------------------------------------------------------------------------
; net_pack_probe_all:
; Scans PCI configuration space across all busses for supported controllers
; Out: EAX = 1 on match, 0 on none
; ------------------------------------------------------------------------------
net_pack_probe_all:
    push rbx
    push r12
    push r13
    push r14
    push r15

    xor r12d, r12d              ; Bus 0..7
.loop_bus:
    xor r13d, r13d              ; Dev 0..31
.loop_dev:
    xor r14d, r14d              ; Func 0..7
.loop_func:
    ; Build PCI config address: 0x80000000 | (Bus<<16) | (Dev<<11) | (Func<<8)
    mov eax, 0x80000000
    mov ebx, r12d
    shl ebx, 16
    or eax, ebx
    mov ebx, r13d
    shl ebx, 11
    or eax, ebx
    mov ebx, r14d
    shl ebx, 8
    or eax, ebx
    mov r15d, eax

    ; Read Vendor + Device ID (Offset 0x00)
    mov dx, 0x0CF8
    out dx, eax
    mov dx, 0x0CFC
    in eax, dx

    cmp eax, 0xFFFFFFFF
    je .next_function
    test eax, eax
    jz .next_function
    mov r8d, eax                ; R8D = (DeviceID << 16) | VendorID

    ; Match Ethernet
    lea rbx, [g_table_ethernet_10]
    mov ecx, ETH_TABLE_ENTRIES
.match_eth:
    cmp [rbx], r8d
    je .on_matched
    add rbx, 8
    dec ecx
    jnz .match_eth

    ; Match Wi-Fi
    lea rbx, [g_table_wifi_40]
    mov ecx, WIFI_TABLE_ENTRIES
.match_wifi:
    cmp [rbx], r8d
    je .on_matched
    add rbx, 8
    dec ecx
    jnz .match_wifi

.next_function:
    inc r14d
    cmp r14d, 8
    jb .loop_func
    inc r13d
    cmp r13d, 32
    jb .loop_dev
    inc r12d
    cmp r12d, 8
    jb .loop_bus

    xor eax, eax
    jmp .exit_probe

.on_matched:
    mov eax, [rbx + 4]
    mov [g_net_pack_active_type], eax
    mov [g_net_pack_active_dev], r8d

    ; Read BAR0 MMIO (Offset 0x10)
    mov eax, r15d
    or eax, 0x10
    mov dx, 0x0CF8
    out dx, eax
    mov dx, 0x0CFC
    in eax, dx
    and eax, 0xFFFFFFF0
    mov [g_net_pack_bar0], rax
    mov [pci_nic_bar0], eax

    ; Enable PCI Bus Master (BME=Bit 2) and Memory Space (MSE=Bit 1)
    mov eax, r15d
    or eax, 0x04
    mov dx, 0x0CF8
    out dx, eax
    mov dx, 0x0CFC
    in eax, dx
    or eax, 0x0007
    mov edx, eax
    mov eax, r15d
    or eax, 0x04
    mov dx, 0x0CF8
    out dx, eax
    pop rax
    mov dx, 0x0CFC
    out dx, eax

    call net_pack_init_ring_descriptors
    mov eax, 1

.exit_probe:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ------------------------------------------------------------------------------
; net_pack_init_ring_descriptors:
; Pre-allocates hardware DMA descriptor rings pointing to contiguous packet pool
; ------------------------------------------------------------------------------
net_pack_init_ring_descriptors:
    push rbx
    push rcx
    push rsi
    push rdi

    lea rdi, [net_pack_rx_ring]
    lea rsi, [net_pack_packet_pool]
    xor ecx, ecx

.setup_rx_descriptors:
    mov r8, rcx
    shl r8, 4
    mov rax, rsi
    mov [rdi + r8 + NetHwDesc.buf_addr_low], eax
    shr rax, 32
    mov [rdi + r8 + NetHwDesc.buf_addr_high], eax
    mov word [rdi + r8 + NetHwDesc.length], 0
    mov byte [rdi + r8 + NetHwDesc.status], 0
    add rsi, PACKET_MAX_LEN
    inc ecx
    cmp ecx, NUM_RX_DESCRIPTORS
    jb .setup_rx_descriptors

    pop rdi
    pop rsi
    pop rcx
    pop rbx
    ret

; ------------------------------------------------------------------------------
; net_pack_route_to_tls13:
; Drops incoming encrypted packet streams directly into web_response_buf
; In: RSI = Raw packet payload, RDX = Payload length in bytes
; ------------------------------------------------------------------------------
net_pack_route_to_tls13:
    push rdi
    push rcx
    push rsi

    lea rdi, [web_response_buf]
    mov rcx, rdx
    cmp rcx, 4096
    jbe .copy_stream
    mov rcx, 4096
.copy_stream:
    cld
    rep movsb

    pop rsi
    pop rcx
    pop rdi
    ret

net_pack_get_device_info:
    mov eax, [g_net_pack_active_dev]
    mov edx, [g_net_pack_active_type]
    ret
