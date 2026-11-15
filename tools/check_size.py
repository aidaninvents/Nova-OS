with open("kernel.asm", "rb") as f:
    content = f.read()

# Fix 1: Fix serial calls
content = content.replace(b"call serial_send_str", b"call serial_send_string")
content = content.replace(b"call serial_send_char", b"mov dx, 0x3F8\r\n    out dx, al")

# Fix 2: Fix mouse calls in NetSurf
# In NetSurf, arrow keys move mouse or resize
content = content.replace(b"call mouse_up", b"cmp dword [mouse_y], 20\r\n    jb .ns_mouse_move\r\n    sub dword [mouse_y], 20")
content = content.replace(b"call mouse_down", b"mov edx, [screen_height]\r\n    sub edx, 30\r\n    cmp dword [mouse_y], edx\r\n    jae .ns_mouse_move\r\n    add dword [mouse_y], 20")
content = content.replace(b"call mouse_left", b"cmp dword [mouse_x], 20\r\n    jb .ns_mouse_move\r\n    sub dword [mouse_x], 20")
content = content.replace(b"call mouse_right", b"mov edx, [screen_width]\r\n    sub edx, 30\r\n    cmp dword [mouse_x], edx\r\n    jae .ns_mouse_move\r\n    add dword [mouse_x], 20")

# Fix 3: Temporarily replace %error with %warning to check exact size
err_target = b'%error "NovaOS kernel is larger than 64 KiB"'
warn_replace = b'%warning Kernel size is over 64k: %[$ - $$]'
content = content.replace(err_target, warn_replace)

with open("kernel.asm", "wb") as f:
    f.write(content)

print("Updated kernel.asm with fixes!")
