with open("kernel.asm", "rb") as f:
    d = f.read()

old_part = (
    b'    db "     Current Server Ver: NovaOS 1.00 26Q4 (Build 26110.0000)",13,10\r\n'
    b'    db "     Local Kernel Build: NovaOS 1.01.0100 (Not Uploaded Yet)",13,10\r\n'
    b'    db "     Included Drivers  : Intel PRO/1000 Ethernet, PS/2 Mouse",13,10\r\n'
    b'    db "     Security          : TLS 1.3 (TLS_AES_256_GCM_SHA384)",13,10\r\n'
    b'    db "     ------------------------------------------------------",13,10\r\n'
    b'    db "     To publish 1.01.0100 to server, open Notepad and click",13,10\r\n'
    b'    db "     File -> Save As (broadcast.txt) when ready!",0'
)

new_part = (
    b'    db "     Current Server Ver: NovaOS 1.01 26Q4 (Build 26110.0001)",13,10\r\n'
    b'    db "     Local Kernel Build: NovaOS 1.01.0000 (Active Release)",13,10\r\n'
    b'    db "     Included Drivers  : Intel PRO/1000 Ethernet, PS/2 Mouse",13,10\r\n'
    b'    db "     Security          : TLS 1.3 (TLS_AES_256_GCM_SHA384)",13,10\r\n'
    b'    db "     ------------------------------------------------------",13,10\r\n'
    b'    db "     Status: Up to date! NovaOS 1.01.0000 is active with   ",13,10\r\n'
    b'    db "     Universal NovaFS Media and 60fps Cinema Engine",0'
)

assert old_part in d, "old_part not found in kernel.asm!"
diff = len(new_part) - len(old_part)
print(f"Old length: {len(old_part)}, New length: {len(new_part)}, Diff: {diff}")
d = d.replace(old_part, new_part, 1)

with open("kernel.asm", "wb") as f:
    f.write(d)
print("Updated kernel.asm release text to NovaOS 1.01.0000!")
