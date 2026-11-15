import subprocess, time, socket, os
from PIL import Image

cmd = [
    'qemu-system-x86_64',
    '-drive', 'format=raw,file=build/novaos.img',
    '-device', 'AC97',
    '-m', '512M',
    '-display', 'none',
    '-monitor', 'tcp:127.0.0.1:4488,server,nowait'
]

p = subprocess.Popen(cmd)
time.sleep(1)

s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect(('127.0.0.1', 4488))
time.sleep(0.5)
s.recv(1024)

# Try sending '2' multiple ways to see if it registers
for attempt in range(5):
    time.sleep(0.5)
    s.sendall(b'sendkey 2\n')
    time.sleep(0.1)
    s.sendall(b'sendkey kp_2\n')
    time.sleep(0.1)
    s.sendall(b'sendkey ret\n')

# Wait for potential boot
time.sleep(2)
s.sendall(b'screendump step1.ppm\n')

# Wait another 16 seconds for 15s timeout to definitely elapse if key was ignored
time.sleep(16)
s.sendall(b'screendump step2.ppm\n')

time.sleep(3)
s.sendall(b'screendump step3.ppm\n')

s.close()
p.terminate()
p.wait()

for step in ['step1', 'step2', 'step3']:
    if os.path.exists(f'{step}.ppm'):
        Image.open(f'{step}.ppm').save(f'{step}.png')
        print(f'Saved {step}.png')
