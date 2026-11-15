import re

with open("kernel.asm", "rb") as f:
    data = f.read()

# 1. Update version text in kernel.asm
data = data.replace(b"NovaOS 1.01.0000", b"NovaOS 1.02.0000")
data = data.replace(b"Build 26110.0001", b"Build 26110.0002")

# 2. Add netsurf command to shell command dispatcher
target_cmd_table = b'    mov rdi, cmd_youtube_short\r\n    call prefix\r\n    jc command_youtube'
replacement_cmd_table = b'''    mov rdi, cmd_youtube_short\r\n    call prefix\r\n    jc command_youtube\r\n    mov rdi, cmd_netsurf_short\r\n    call prefix\r\n    jc command_netsurf'''

assert target_cmd_table in data, "target_cmd_table not found!"
data = data.replace(target_cmd_table, replacement_cmd_table, 1)

# Add cmd_netsurf_short to strings
target_str_yt = b'cmd_youtube_short: db "youtube",0'
replacement_str_yt = b'''cmd_youtube_short: db "youtube",0\r\ncmd_netsurf_short: db "netsurf",0'''
assert target_str_yt in data, "target_str_yt not found!"
data = data.replace(target_str_yt, replacement_str_yt, 1)

with open("kernel.asm", "wb") as f:
    f.write(data)
print("Updated command dispatcher for netsurf!")
