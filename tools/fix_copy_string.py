with open("kernel.asm", "rb") as f:
    data = f.read()

target = b'command_netsurf:\n'
if target not in data:
    target = b'command_netsurf:\r\n'

copy_string_func = b'''copy_string:
    push rax
    push rsi
    push rdi
.cs_loop:
    lodsb
    stosb
    test al, al
    jnz .cs_loop
    pop rdi
    pop rsi
    pop rax
    ret

'''

data = data.replace(target, copy_string_func + target, 1)

with open("kernel.asm", "wb") as f:
    f.write(data)

print("Added copy_string subroutine!")
