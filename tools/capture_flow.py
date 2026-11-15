import subprocess, time, socket, os
cmd = ['qemu-system-x86_64', '-drive', 'format=raw,file=build/novaos.img', '-device', 'AC97', '-m', '512M', '-display', 'none', '-monitor', 'tcp:127.0.0.1:4449,server,nowait']
p = subprocess.Popen(cmd)
time.sleep(3.5) # Wait for stage2 resolution menu

s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect(('127.0.0.1', 4449))
time.sleep(0.5)
s.recv(1024)

# Select mode 2 (1024x768)
s.sendall(b'sendkey 2\n')
time.sleep(1.2)

# Dump boot screen
s.sendall(b'screendump screen_boot.ppm\n')
time.sleep(2.5) # Wait for spinner to finish and desktop to load

# Dump desktop screen
s.sendall(b'screendump screen_desktop.ppm\n')
time.sleep(1)

s.close()
p.terminate()
p.wait()

from PIL import Image
if os.path.exists('screen_boot.ppm'):
    Image.open('screen_boot.ppm').save('screen_boot.png')
    print('Saved screen_boot.png')
if os.path.exists('screen_desktop.ppm'):
    Image.open('screen_desktop.ppm').save('screen_desktop.png')
    print('Saved screen_desktop.png')
