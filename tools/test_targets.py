import os

with open(r"c:\Users\aidan\Downloads\NovaOS_fixed\NovaOS_fixed\kernel.asm", "rb") as f:
    d = f.read()

t1 = b'fs_logo_name db "NOVALOGO.RAW",0'
print("t1:", t1 in d)

t2 = b'    jc load_logo_found\r\n\r\n    ; ------------------------------------------------------------\r\n    ; Next directory entry.'
print("t2:", t2 in d)

t3 = b'load_logo_found:\r\n\r\n    call fs_entry_address\r\n\r\n    mov [logo_address], rax\r\n\r\n    jmp load_font_next_entry'
print("t3:", t3 in d)

t4 = b'; DRAW RAW 32-BPP BGRA IMAGE (HIGH SPEED ASSEMBLY BLITTER)'
print("t4:", t4 in d)

idx5 = d.find(b'.skip_cinema_bg:')
print("idx5:", idx5)
if idx5 != -1:
    print("t5 snippet:", repr(d[idx5:idx5+100]))
