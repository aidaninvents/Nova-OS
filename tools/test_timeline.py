import subprocess, time, socket, os
from PIL import Image

sock_path = "/tmp/qemu_timeline.sock"
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

# Capture at seconds: 5, 8, 12, 16, 20, 25
snaps = [5, 8, 12, 16, 20, 25]
curr = 1.0
for target in snaps:
    wait = target - curr
    if wait > 0:
        time.sleep(wait)
    curr = target
    ppm = f"/tmp/t_{target}.ppm"
    s.sendall(f"screendump {ppm}\n".encode())
    time.sleep(0.2)

s.close()
p.terminate()
p.wait()

for target in snaps:
    ppm = f"/tmp/t_{target}.ppm"
    png = f"timeline_{target}s.png"
    if os.path.exists(ppm):
        im = Image.open(ppm)
        im.save(png)
        colors = len(set(im.getdata()))
        print(f"t={target}s: size={im.size}, unique_colors={colors}")
