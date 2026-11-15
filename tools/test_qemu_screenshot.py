import subprocess
import time
import os

# Run QEMU with monitor on a socket or stdio
cmd = [
    "qemu-system-x86_64",
    "-drive", "format=raw,file=build/novaos.img",
    "-m", "512M",
    "-display", "none",
    "-monitor", "tcp:127.0.0.1:4444,server,nowait"
]

proc = subprocess.Popen(cmd)
time.sleep(2)

import socket
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect(("127.0.0.1", 4444))
time.sleep(0.5)

# Receive banner
s.recv(1024)

# Send key '2' for 1024x768 (or '1' for 480p)
s.sendall(b"sendkey 2\n")
time.sleep(0.5)
s.sendall(b"sendkey kp_2\n")
time.sleep(0.5)
s.sendall(b"sendkey spc\n") # skip boot animation if any
time.sleep(3)

# Dump screenshot
s.sendall(b"screendump qemu_screen.ppm\n")
time.sleep(1)

s.close()
proc.terminate()
proc.wait()

if os.path.exists("qemu_screen.ppm"):
    from PIL import Image
    im = Image.open("qemu_screen.ppm")
    im.save("qemu_screen.png")
    print(f"Saved qemu_screen.png, size={im.size}")
else:
    print("screendump failed")
