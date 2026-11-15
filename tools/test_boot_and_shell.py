import subprocess, time, socket, os
from PIL import Image

cmd = [
    'qemu-system-x86_64',
    '-drive', 'format=raw,file=build/novaos.img',
    '-device', 'AC97',
    '-m', '512M',
    '-display', 'none',
    '-monitor', 'tcp:127.0.0.1:4466,server,nowait'
]

p = subprocess.Popen(cmd)

s = None
for _ in range(30):
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.connect(('127.0.0.1', 4466))
        break
    except Exception:
        time.sleep(0.5)

if not s:
    print('Failed to connect to QEMU monitor')
    p.terminate()
    exit(1)

time.sleep(1.0)
try:
    s.recv(1024)
except Exception:
    pass

# We are in stage2 resolution menu. Wait 1 second and send '2' for 1024x768
time.sleep(1.0)
s.sendall(b'sendkey 2\n')

# Boot hardware info + spinner animation runs now
# Let's capture boot screen at 0.5s after mode selection
time.sleep(0.5)
s.sendall(b'screendump screen_boot_test.ppm\n')

# Wait for spinner to finish and desktop to load (about 2.5s)
time.sleep(2.5)

# Capture initial desktop
s.sendall(b'screendump screen_desktop_init.ppm\n')
time.sleep(0.5)

# Type commands into shell: 'drives', 'cpu', 'mem', 'floppy'
for cmd_text in ['drives', 'cpu', 'mem', 'floppy']:
    for ch in cmd_text:
        s.sendall(f'sendkey {ch}\n'.encode())
        time.sleep(0.04)
    s.sendall(b'sendkey ret\n')
    time.sleep(0.2)

time.sleep(1.0)
s.sendall(b'screendump screen_shell_test.ppm\n')
time.sleep(1.0)

s.close()
p.terminate()
p.wait()

for name in ['screen_boot_test', 'screen_desktop_init', 'screen_shell_test']:
    ppm = f'{name}.ppm'
    png = f'{name}.png'
    if os.path.exists(ppm):
        Image.open(ppm).save(png)
        print(f'Saved {png}')
