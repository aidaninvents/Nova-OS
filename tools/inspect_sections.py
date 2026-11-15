with open("kernel.asm", "rb") as f:
    data = f.read()

# Let's check sections in kernel.asm
# 1. font_setup
print("font_setup size:", len(data[data.find(b'command_font_setup:'):data.find(b'command_wifi:')]))
# 2. files
print("files size:", len(data[data.find(b'command_files:'):data.find(b'command_res:')]))
# 3. chrome
print("chrome size:", len(data[data.find(b'command_chrome:'):data.find(b'command_shop:')]))
# 4. shop
print("shop size:", len(data[data.find(b'command_shop:'):data.find(b'command_notepad:')]))
# 5. notepad
print("notepad size:", len(data[data.find(b'command_notepad:'):data.find(b'command_python:')]))
# 6. netsurf
print("netsurf size:", len(data[data.find(b'command_netsurf:'):data.find(b'command_video:')]))
# 7. youtube
print("youtube size:", len(data[data.find(b'command_youtube:'):data.find(b'command_add:')]))
