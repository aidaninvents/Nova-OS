with open("kernel.asm", "rb") as f:
    data = f.read()

target = b'''    mov rsi, input\r
    call skip_spaces\r
    mov rdi, cmd_youtube_short\r
    call prefix\r
    jc command_youtube\r
'''

replacement = b'''    mov rsi, input\r
    call skip_spaces\r
    mov rdi, cmd_youtube_short\r
    call prefix\r
    jc command_youtube\r
\r
    mov rsi, input\r
    call skip_spaces\r
    mov rdi, cmd_netsurf_short\r
    call prefix\r
    jc command_netsurf\r
'''

assert target in data, "Target dispatch block not found!"
data = data.replace(target, replacement, 1)

with open("kernel.asm", "wb") as f:
    f.write(data)

print("Added netsurf to .check_direct_nosp dispatch loop!")
