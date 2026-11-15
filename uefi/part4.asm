; Part 4/4: data (strings, GUIDs, paths, state)
msg_hello   dw __utf16__("NovaOS UEFI loader"), 13, 10, 0
msg_mode    dw __utf16__("GOP mode: "), 0
msg_x       dw __utf16__("x"), 0
msg_nl      dw __utf16__(""), 13, 10, 0
msg_jump    dw __utf16__("Starting kernel..."), 13, 10, 0
msg_fail    dw __utf16__("UEFI boot failure."), 13, 10, 0
msg_nogop   dw __utf16__("No suitable GOP mode."), 13, 10, 0
msg_nofs    dw __utf16__("Payload files missing/bad."), 13, 10, 0
path_kernel dw 92,'E',0,'F',0,'I',0,92,'N',0,'O',0,'V',0,'A',0,92,'K',0,'E',0,'R',0,'N',0,'E',0,'L',0,'.',0,'B',0,'I',0,'N',0,0
path_fs     dw 92,'E',0,'F',0,'I',0,92,'N',0,'O',0,'V',0,'A',0,92,'N',0,'O',0,'V',0,'A',0,'F',0,'S',0,'.',0,'B',0,'I',0,'N',0,0
guid_gop    db 0xDE,0xA9,0x42,0x90,0xDC,0x73,0x13,0x4D,0xB9,0xCA,0x67,0x63,0x0E,0xB4,0x57,0xA8
guid_fs     db 0x96,0x45,0x22,0x5D,0x59,0x72,0xC3,0x11,0x9A,0x11,0x00,0x90,0x27,0x3E,0xFC,0x61
guid_loaded db 0xA1,0x31,0x1B,0x5C,0x62,0x95,0xD2,0x11,0x8E,0x3F,0x00,0xA0,0xC9,0x69,0x72,0x3B
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
