#!/usr/bin/env python3
"""Build NovaOS UEFI loader: assemble uefi/loader.asm with nasm, wrap as PE32+ .efi."""
import struct, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
UEFI = ROOT / "uefi"
BUILD = ROOT / "build"
BUILD.mkdir(parents=True, exist_ok=True)

IMAGE_BASE = 0x140000000
SEC_RVA, SEC_OFF = 0x1000, 0x200
FILE_ALIGN, SEC_ALIGN = 0x200, 0x1000

src_asm = UEFI / "loader.asm"
bin_path = UEFI / "loader.bin"

# Assemble loader.asm
r = None
try:
    r = subprocess.run(["nasm", "-f", "bin", str(src_asm), "-o", str(bin_path)],
                       capture_output=True, text=True)
except FileNotFoundError:
    pass

if r is None or r.returncode != 0:
    r = subprocess.run(["wsl.exe", "-d", "Ubuntu", "--", "bash", "-c",
                        f"cd /mnt/c/Users/aidan/Downloads/NovaOS_fixed/NovaOS_fixed && nasm -f bin uefi/loader.asm -o uefi/loader.bin"],
                       capture_output=True, text=True)

if r.stdout:
    print(r.stdout)
if r.stderr:
    print(r.stderr, file=sys.stderr)
if r.returncode != 0:
    print(f"[EFI] Failed to assemble {src_asm}")
    sys.exit(r.returncode)

code = bin_path.read_bytes()
vsize = len(code)
raw = (len(code) + FILE_ALIGN - 1) // FILE_ALIGN * FILE_ALIGN
code += b"\x00" * (raw - len(code))

nhdr = 0x40 + 4 + 20 + 240 + 40
assert nhdr <= SEC_OFF
hdr = bytearray(SEC_OFF)
hdr[0:2] = b"MZ"
struct.pack_into("<I", hdr, 0x3C, 0x40)
hdr[0x40:0x44] = b"PE\x00\x00"
coff = 0x44
struct.pack_into("<HHIIIHH", hdr, coff, 0x8664, 1, 0, 0, 0, 240, 0x22)
op = coff + 20
struct.pack_into("<H", hdr, op, 0x20B)
hdr[op+2:op+4] = b"\x02\x1E"
struct.pack_into("<IIIII", hdr, op+4, raw, raw, 0, SEC_RVA, SEC_RVA)  # code, idata, udata, entry, codebase
struct.pack_into("<Q", hdr, op+24, IMAGE_BASE)
struct.pack_into("<II", hdr, op+32, SEC_ALIGN, FILE_ALIGN)
struct.pack_into("<HHHHHH", hdr, op+40, 6, 0, 0, 0, 6, 0)
struct.pack_into("<I", hdr, op+60, SEC_OFF)
sec_span = (vsize + SEC_ALIGN - 1) // SEC_ALIGN * SEC_ALIGN
img_size = SEC_RVA + sec_span
struct.pack_into("<I", hdr, op+56, img_size)
struct.pack_into("<H", hdr, op+68, 10)          # subsystem EFI application
struct.pack_into("<Q", hdr, op+72, 0x10000)     # stack reserve/commit
struct.pack_into("<Q", hdr, op+80, 0x10000)
struct.pack_into("<I", hdr, op+92, 0)           # certs=0
struct.pack_into("<I", hdr, op+108, 16)         # nrva
sh = coff + 20 + 240
hdr[sh:sh+8] = b".text\x00\x00\x00"
struct.pack_into("<IIIIIIHHI", hdr, sh+8, vsize, SEC_RVA, raw, SEC_OFF,
                 0, 0, 0, 0, 0x60000020)

out = BUILD / "BOOTX64.EFI"
out.write_bytes(bytes(hdr) + code)
print(f"[EFI] Generated {out} ({out.stat().st_size} bytes, code={vsize} bytes)")
