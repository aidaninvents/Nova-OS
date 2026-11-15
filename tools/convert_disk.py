import subprocess, sys

src = "/mnt/c/Users/aidan/Downloads/NovaOS_fixed/NovaOS_fixed/build/target_disk.raw"
dst = "/mnt/c/Users/aidan/VirtualBox VMs/Nova OS/Nova OS_1.vdi"

cmd = ["qemu-img", "convert", "-f", "raw", "-O", "vdi", src, dst]
print("Running:", " ".join(cmd))
res = subprocess.run(cmd, capture_output=True, text=True)
if res.returncode != 0:
    print("Error:", res.stderr)
    sys.exit(res.returncode)
print("Successfully converted to VDI!")
