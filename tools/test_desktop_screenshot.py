import subprocess
import time
import os
import socket

cmd = [
    "qemu-system-x86_64",
    "-drive", "format=raw,file=build/novaos.img",
    "-m", "512M",
    "-display", "none",
    "-monitor", "tcp:127.0.0.1:4445,server,nowait"
]

proc = subprocess.Popen(cmd)
time.sleep(2)

s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect(("127.0.0.1", 4445))
time.sleep(0.5)
s.recv(1024)

# Send key 2
s.sendall(b"sendkey 2\n")
time.sleep(1)
# Send key to skip boot screen
s.sendall(b"sendkey spc\n")
# Wait for desktop to draw
time.sleep(4)

s.sendall(b"screendump desktop_screen.ppm\n")
time.sleep(1)

s.close()
proc.terminate()
proc.wait()

if os.path.exists("desktop_screen.ppm"):
    from PIL import Image
    im = Image.open("desktop_screen.ppm")
    im.save("desktop_screen.png")
    print(f"Saved desktop_screen.png, size={im.size}")
