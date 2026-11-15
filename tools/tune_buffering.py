with open("kernel.asm", "rb") as f:
    d = f.read()

target1 = b'str_yt_buffering db "Buffering 1080p60 stream from www.youtube.com (TLS 1.3)...",0'
replacement1 = b'str_yt_buffering db "Buffering YouTube 60fps stream (TLS 1.3)...",0'
assert target1 in d, "target1 not found!"
d = d.replace(target1, replacement1, 1)

target2 = b'mov byte [cursor_x], 18\r\n    mov byte [cursor_y], 15\r\n    mov rsi, str_yt_buffering'
replacement2 = b'mov byte [cursor_x], 28\r\n    mov byte [cursor_y], 14\r\n    mov rsi, str_yt_buffering'
assert target2 in d, "target2 not found!"
d = d.replace(target2, replacement2, 1)

with open("kernel.asm", "wb") as f:
    f.write(d)
print("Updated buffering string and cursor cleanly!")
