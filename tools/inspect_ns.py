with open("kernel.asm", "rb") as f:
    data = f.read()

idx_ns = data.find(b'command_netsurf:')
idx_vid = data.find(b'command_video:')
print("command_netsurf total length in bytes:", idx_vid - idx_ns)

# Check draw_rect calls
lines = data[idx_ns:idx_vid].split(b'\n')
rect_count = sum(1 for line in lines if b'call draw_rect' in line)
print("draw_rect calls in netsurf:", rect_count)
