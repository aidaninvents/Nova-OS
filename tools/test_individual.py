import subprocess, time, socket, os
from PIL import Image

def run_test(cmd_name):
    sock = f"/tmp/q_{cmd_name}.sock"
    if os.path.exists(sock):
        os.remove(sock)
    p = subprocess.Popen(["qemu-system-x86_64", "-drive", "format=raw,file=build/novaos.img", "-m", "512M", "-display", "none", "-monitor", f"unix:{sock},server,nowait"])
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    for _ in range(50):
        time.sleep(0.1)
        if os.path.exists(sock):
            try:
                s.connect(sock)
                break
            except Exception:
                pass
    time.sleep(8.0)
    for ch in cmd_name:
        s.sendall(f"sendkey {ch}\n".encode())
        time.sleep(0.05)
    s.sendall(b"sendkey ret\n")
    time.sleep(0.5)
    ppm = f"/tmp/{cmd_name}.ppm"
    s.sendall(f"screendump {ppm}\n".encode())
    time.sleep(0.5)
    s.close()
    p.terminate()
    p.wait()
    if os.path.exists(ppm):
        im = Image.open(ppm)
        im.save(f"{cmd_name}_check.png")
        print(f"{cmd_name} result: size={im.size}")

run_test("floppy")
run_test("cpu")
run_test("mem")
