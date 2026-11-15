with open("kernel.asm", "rb") as f:
    data = f.read()

crlf = b"\r\n" in data
def nl(s: str) -> bytes:
    return (s.replace("\n", "\r\n") if crlf else s).encode("ascii")

old_sync = """    ; AC'97 Hardware Lip-Sync using BDL descriptor + PO_PICB
    mov r15d, 1000000
.hd_sync_loop:
    call yt_handle_input"""

new_sync = """    ; AC'97 Hardware Lip-Sync (CPU idle spin between port polls -> zero VM-exit starvation!)
    mov r15d, 60
.hd_sync_loop:
    mov ecx, 120000
.hd_cpu_idle:
    pause
    dec ecx
    jnz .hd_cpu_idle

    call yt_handle_input"""

assert nl(old_sync) in data, "old_sync not found"
data = data.replace(nl(old_sync), nl(new_sync), 1)

with open("kernel.asm", "wb") as f:
    f.write(data)
print("Patched .hd_sync_loop to prevent VM-exit audio starvation!")
