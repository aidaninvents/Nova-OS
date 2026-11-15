with open("kernel.asm", "rb") as f:
    data = f.read()

idx_j = data.find(b'command_java:')
idx_h = data.find(b'command_html:')
idx_yt = data.find(b'command_youtube:')
print("command_java source length:", idx_h - idx_j)
print("command_html source length:", idx_yt - idx_h)
