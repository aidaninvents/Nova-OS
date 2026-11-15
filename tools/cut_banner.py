with open("kernel.asm", "rb") as f:
    data = f.read()

target = b'str_python_banner_102: db "Python 3.15.0 (NovaOS 1.02 Real Bridge Engine, 64-bit x86_64)",13,10,"Type \'help\', \'copyright\', \'credits\' or \'license\' for more information.",13,10,0'
replacement = b'str_python_banner_102: db "Python 3.15.0 (NovaOS 1.02, 64-bit)",13,10,0'

assert target in data, "Target not found"
data = data.replace(target, replacement, 1)

with open("kernel.asm", "wb") as f:
    f.write(data)

print("Trimmed 135 bytes from python banner successfully!")
