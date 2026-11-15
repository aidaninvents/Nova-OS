import subprocess, time, socket, os
from PIL import Image

sock_path = "/tmp/qemu_snap2.sock"
if os.path.exists(sock_path):
    os.remove(sock_path)

cmd = [
    "qemu-system-x86_64",
    "-drive", "format=raw,file=build/novaos.img",
    "-m", "512M",
    "-display", "none",
    "-monitor", f"unix:{sock_path},server,nowait"
]
p = subprocess.Popen(cmd)

s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
for _ in range(50):
    time.sleep(0.1)
    if os.path.exists(sock_path):
        try:
            s.connect(sock_path)
            break
        except Exception:
            pass

time.sleep(1.0)
try:
    s.recv(1024)
except Exception:
    pass

# Stage2 auto-boots at ~4.5s.
# At 5.5s, boot screen is active with hardware detection info & spinner
time.sleep(4.5)
s.sendall(b"screendump /tmp/final_boot.ppm\n")

# Wait 3.5s (t = 9.0s). Spinner (~1.0s) and chimes (~0.2s) complete, desktop renders
time.sleep(3.5)
s.sendall(b"screendump /tmp/final_desktop.ppm\n")

# Send shell commands
time.sleep(0.5)
for cmd_str in ["drives", "cpu", "mem", "floppy"]:
    for ch in cmd_str:
        s.sendall(f"sendkey {ch}\n".encode())
        time.sleep(0.04)
    s.sendall(b"sendkey ret\n")
    time.sleep(0.3)

time.sleep(1.0)
s.sendall(b"screendump /tmp/final_shell.ppm\n")
time.sleep(0.5)

s.close()
p.terminate()
p.wait()

for name in ["final_boot", "final_desktop", "final_shell"]:
    ppm = f"/tmp/{name}.ppm"
    png = f"{name}.png"
    if os.path.exists(ppm):
        im = Image.open(ppm)
        im.save(png)
        print(f"Saved {png}, size={im.size}, colors={len(set(im.getdata()))}")
