with open("kernel.asm", "rb") as f:
    lines = f.readlines()
long_strs = []
for i, line in enumerate(lines):
    if b'db "' in line and len(line) > 50:
        long_strs.append((i+1, len(line), line.strip()[:80]))
long_strs.sort(key=lambda x: x[1], reverse=True)
for item in long_strs[:20]:
    print(f"Line {item[0]}: length {item[1]}: {item[2]}")
