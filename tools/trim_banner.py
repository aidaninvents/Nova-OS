with open("kernel.asm", "rb") as f:
    data = f.read()

old_banner = b'str_python_banner_102: db "Python 3.15.0 (NovaOS 1.02 Real Bridge Engine, 64-bit Core, GCC Freestanding Native)"'
new_banner = b'str_python_banner_102: db "Python 3.15.0 (NovaOS 1.02, 64-bit)"'

old_ns = b'str_ns_page_body1:  db "Official NetSurf C Browser from GitHub! Frontends: Framebuffer (libnsfb), SDL2, GTK, and AmigaOS.",0'
new_ns = b'str_ns_page_body1:  db "Official NetSurf C Browser from GitHub!",0'

if old_banner in data:
    data = data.replace(old_banner, new_banner, 1)
    print("Replaced old_banner")

if old_ns in data:
    data = data.replace(old_ns, new_ns, 1)
    print("Replaced old_ns (saved 75 bytes)")

with open("kernel.asm", "wb") as f:
    f.write(data)
