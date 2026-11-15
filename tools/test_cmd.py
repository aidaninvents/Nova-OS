import subprocess, time, socket, os
from PIL import Image

sock_path = "/tmp/qemu_cmd_test3.sock"
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

# Wait for desktop to be fully up and ready (10 seconds)
time.sleep(10.0)

# Run floppy, cpu, mem
for cmd_text in ["floppy", "cpu", "mem"]:
    for ch in cmd_text:
        s.sendall(f"sendkey {ch}\n".encode())
        time.sleep(0.06)
    s.sendall(b"sendkey ret\n")
    time.sleep(0.5)

time.sleep(1.0)
s.sendall(b"screendump /tmp/commands_check.ppm\n")
time.sleep(0.5)

s.close()
p.terminate()
p.wait()

ppm = "/tmp/commands_check.ppm"
png = "commands_check.png"
if os.path.exists(ppm):
    im = Image.open(ppm)
    im.save(png)
    print(f"Saved {png}, size={im.size}, colors={len(set(im.getdata()))}")
