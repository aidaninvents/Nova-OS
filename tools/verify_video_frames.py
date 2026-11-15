import subprocess, time, os, struct, zlib

VBOX = r"C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
VM = "Nova OS"
ART_DIR = r"C:\Users\aidan\.gemini\antigravity\brain\ba770e27-cfc2-4b4e-be8f-1af3e0a2b90f"

def read_png_viewport(path, vx=192, vy=110, vw=640, vh=480):
    with open(path, "rb") as f:
        sig = f.read(8)
        assert sig == b"\x89PNG\r\n\x1a\n"
        idat = bytearray()
        w = h = 0
        while True:
            hdr = f.read(8)
            if not hdr:
                break
            length, ctype = struct.unpack(">I4s", hdr)
            chunk = f.read(length)
            f.read(4)
            if ctype == b"IHDR":
                w, h = struct.unpack(">II", chunk[:8])
            elif ctype == b"IDAT":
                idat.extend(chunk)
            elif ctype == b"IEND":
                break
    raw = zlib.decompress(bytes(idat))
    bpp = 4 if len(raw) >= h * (w * 4 + 1) else 3
    stride = w * bpp
    recon = bytearray(h * stride)
    for y in range(h):
        ftype = raw[y * (stride + 1)]
        row_in = raw[y * (stride + 1) + 1 : (y + 1) * (stride + 1)]
        row_out = y * stride
        for x in range(stride):
            val = row_in[x]
            a = recon[row_out + x - bpp] if x >= bpp else 0
            b = recon[row_out - stride + x] if y > 0 else 0
            c = recon[row_out - stride + x - bpp] if (y > 0 and x >= bpp) else 0
            if ftype == 1:
                val = (val + a) & 0xFF
            elif ftype == 2:
                val = (val + b) & 0xFF
            elif ftype == 3:
                val = (val + ((a + b) >> 1)) & 0xFF
            elif ftype == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                val = (val + pr) & 0xFF
            recon[row_out + x] = val
    # Extract viewport RGB bytes
    vp = bytearray()
    for y in range(vy, vy + vh):
        start = y * stride + vx * bpp
        vp.extend(recon[start : start + vw * bpp])
    return bytes(vp)

print("[1] Waiting 3s for desktop, launching YouTube...")
time.sleep(3)
subprocess.run(["python", "tools/send_keys.py", "youtube"], check=True)
time.sleep(2)

print("[2] Starting Video 1 (Me at the zoo) and capturing consecutive frames...")
subprocess.run(["python", "tools/send_keys.py", "1", "--raw"], check=True)

captures = []
t0 = time.monotonic()
for step in range(13):
    target_t = 1.0 + step * 2.0
    dt = target_t - (time.monotonic() - t0)
    if dt > 0:
        time.sleep(dt)
    elapsed = time.monotonic() - t0
    out_png = os.path.join(ART_DIR, f"vbox_270_seq_{step:02d}_{int(elapsed):02d}s.png")
    subprocess.run([VBOX, "controlvm", VM, "screenshotpng", out_png], check=True)
    captures.append((elapsed, out_png))
    print(f"  Captured t={elapsed:.2f}s -> {os.path.basename(out_png)}")

print("\n[3] Comparing consecutive viewport pixels (576x432) across timeline:")
prev_vp = None
prev_name = None
for elapsed, path in captures:
    vp = read_png_viewport(path)
    name = os.path.basename(path)
    if prev_vp is not None:
        # Compare byte-level pixel motion (subsample every 4th byte or full diff)
        diff_bytes = sum(1 for a, b in zip(prev_vp[::4], vp[::4]) if abs(a - b) > 4)
        total_px = len(prev_vp) // 4
        pct = 100.0 * diff_bytes / total_px
        print(f"  {prev_name} -> {name}: {pct:.2f}% pixels changed ({diff_bytes}/{total_px})")
    prev_vp = vp
    prev_name = name
