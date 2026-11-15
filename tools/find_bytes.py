with open("kernel.asm", "rb") as f:
    data = f.read()
idx = data.find(b"load_logo_found")
print("idx:", idx)
if idx != -1:
    print(data[idx-150:idx+200])
