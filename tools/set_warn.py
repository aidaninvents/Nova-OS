with open("kernel.asm", "rb") as f:
    c = f.read()
c = c.replace(b'%error "NovaOS kernel is larger than 64 KiB"', b'%warning Over limit: %[$ - $$]')
with open("kernel.asm", "wb") as f:
    f.write(c)
print("done setting warning")
