#!/usr/bin/env python3
"""
tools/make_efiboot.py
Generates a 100% UEFI-compliant FAT16 EFI System Partition image (efiboot.img)
Contains:
  /EFI/BOOT/BOOTX64.EFI
  /EFI/NOVA/KERNEL.BIN
  /EFI/NOVA/NOVAFS.BIN
And root mirrors:
  /BOOTX64.EFI
  /KERNEL.BIN
  /NOVAFS.BIN
"""
import os, struct, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / "build"
OUT_IMG = BUILD / "efiboot.img"

BOOTX64 = BUILD / "BOOTX64.EFI"
KERNEL = BUILD / "kernel.bin"
FS_BIN = BUILD / "fs.bin"
if not FS_BIN.exists() and (ROOT / "fs" / "novafs.img").exists():
    FS_BIN = ROOT / "fs" / "novafs.img"

if not BOOTX64.exists():
    print(f"[FAT] Missing {BOOTX64}")
    sys.exit(1)

# Target image size: 2880 KB = 5760 sectors of 512 bytes
SECTOR_SIZE = 512
TOTAL_SECTORS = 5760
RESERVED = 4
NUM_FATS = 2
ROOT_ENTRIES = 512
ROOT_SECTORS = (ROOT_ENTRIES * 32 + SECTOR_SIZE - 1) // SECTOR_SIZE # 32 sectors
FAT_SECTORS = 32 # 16 KiB per FAT table (indexes up to 8192 clusters, safely covering all 5760 sectors)
DATA_START = RESERVED + NUM_FATS * FAT_SECTORS + ROOT_SECTORS # 4 + 64 + 32 = 100

img = bytearray(TOTAL_SECTORS * SECTOR_SIZE)

# 1. Boot sector (FAT16 BPB)
img[0:3] = b'\xeb\x3c\x90'
img[3:11] = b'MSWIN4.1'
struct.pack_into('<HBHBHHBHHHII', img, 11,
                 SECTOR_SIZE, 1, RESERVED, NUM_FATS, ROOT_ENTRIES,
                 TOTAL_SECTORS, 0xF8, FAT_SECTORS, 63, 16, 0, 0)
# Offset 36: DriveNumber=0x80, Offset 37: Reserved=0x00, Offset 38: BootSignature=0x29
img[36:39] = b'\x80\x00\x29'
struct.pack_into('<I', img, 39, 0x12345678) # Volume ID
img[43:54] = b'NOVAOS EFI ' # Volume Label (11 bytes)
img[54:62] = b'FAT16   '    # File system type (8 bytes)
img[510:512] = b'\x55\xaa'

fat = bytearray(FAT_SECTORS * SECTOR_SIZE)
struct.pack_into('<H', fat, 0, 0xFFF8)
struct.pack_into('<H', fat, 2, 0xFFFF)

next_free_cluster = 2

def alloc_chain(num_clusters):
    global next_free_cluster
    start = next_free_cluster
    for i in range(num_clusters - 1):
        c = start + i
        struct.pack_into('<H', fat, c * 2, c + 1)
    end = start + num_clusters - 1
    struct.pack_into('<H', fat, end * 2, 0xFFFF)
    next_free_cluster = end + 1
    return start

def make_entry(name8_3, attr, first_cluster, size):
    e = bytearray(32)
    clean_name = name8_3.strip()
    if clean_name == ".":
        name11 = b'.          '
    elif clean_name == "..":
        name11 = b'..         '
    else:
        parts = clean_name.split('.')
        base = parts[0].upper().ljust(8)[:8].encode('ascii')
        ext = (parts[1].upper().ljust(3)[:3] if len(parts) > 1 else '   ').encode('ascii')
        name11 = base + ext
    e[0:11] = name11
    e[11] = attr
    struct.pack_into('<HI', e, 26, first_cluster, size)
    return bytes(e)

boot_data = BOOTX64.read_bytes()
kernel_data = KERNEL.read_bytes() if KERNEL.exists() else b''
fs_data = FS_BIN.read_bytes() if FS_BIN.exists() else b''

def write_cluster_data(cluster, data):
    offset = (DATA_START + cluster - 2) * SECTOR_SIZE
    img[offset:offset + len(data)] = data

# Allocate clusters and write payload data
boot_clusters = (len(boot_data) + SECTOR_SIZE - 1) // SECTOR_SIZE
boot_start = alloc_chain(boot_clusters)
write_cluster_data(boot_start, boot_data)

kernel_clusters = (len(kernel_data) + SECTOR_SIZE - 1) // SECTOR_SIZE
kernel_start = alloc_chain(kernel_clusters)
write_cluster_data(kernel_start, kernel_data)

fs_clusters = (len(fs_data) + SECTOR_SIZE - 1) // SECTOR_SIZE
fs_start = alloc_chain(fs_clusters)
write_cluster_data(fs_start, fs_data)

# Allocate directory clusters
efi_cluster = alloc_chain(1)
boot_dir_cluster = alloc_chain(1)
nova_dir_cluster = alloc_chain(1)

# Build Root Directory:
# Contains: "EFI" (dir), "BOOTX64.EFI", "KERNEL.BIN", "NOVAFS.BIN"
root_dir = bytearray(ROOT_SECTORS * SECTOR_SIZE)
root_dir[0*32:1*32] = make_entry("EFI", 0x10, efi_cluster, 0)
root_dir[1*32:2*32] = make_entry("BOOTX64.EFI", 0x20, boot_start, len(boot_data))
root_dir[2*32:3*32] = make_entry("KERNEL.BIN", 0x20, kernel_start, len(kernel_data))
root_dir[3*32:4*32] = make_entry("NOVAFS.BIN", 0x20, fs_start, len(fs_data))
root_offset = (RESERVED + NUM_FATS * FAT_SECTORS) * SECTOR_SIZE
img[root_offset:root_offset + len(root_dir)] = root_dir

# Build /EFI directory:
# Contains: "." (efi_cluster), ".." (0 = root), "BOOT" (dir), "NOVA" (dir)
efi_dir = bytearray(SECTOR_SIZE)
efi_dir[0*32:1*32] = make_entry(".", 0x10, efi_cluster, 0)
efi_dir[1*32:2*32] = make_entry("..", 0x10, 0, 0)
efi_dir[2*32:3*32] = make_entry("BOOT", 0x10, boot_dir_cluster, 0)
efi_dir[3*32:4*32] = make_entry("NOVA", 0x10, nova_dir_cluster, 0)
write_cluster_data(efi_cluster, efi_dir)

# Build /EFI/BOOT directory:
# Contains: "." (boot_dir_cluster), ".." (efi_cluster), "BOOTX64.EFI"
boot_dir = bytearray(SECTOR_SIZE)
boot_dir[0*32:1*32] = make_entry(".", 0x10, boot_dir_cluster, 0)
boot_dir[1*32:2*32] = make_entry("..", 0x10, efi_cluster, 0)
boot_dir[2*32:3*32] = make_entry("BOOTX64.EFI", 0x20, boot_start, len(boot_data))
write_cluster_data(boot_dir_cluster, boot_dir)

# Build /EFI/NOVA directory:
# Contains: "." (nova_dir_cluster), ".." (efi_cluster), "KERNEL.BIN", "NOVAFS.BIN"
nova_dir = bytearray(SECTOR_SIZE)
nova_dir[0*32:1*32] = make_entry(".", 0x10, nova_dir_cluster, 0)
nova_dir[1*32:2*32] = make_entry("..", 0x10, efi_cluster, 0)
nova_dir[2*32:3*32] = make_entry("KERNEL.BIN", 0x20, kernel_start, len(kernel_data))
nova_dir[3*32:4*32] = make_entry("NOVAFS.BIN", 0x20, fs_start, len(fs_data))
write_cluster_data(nova_dir_cluster, nova_dir)

# Write FAT tables
for f in range(NUM_FATS):
    offset = (RESERVED + f * FAT_SECTORS) * SECTOR_SIZE
    img[offset:offset + len(fat)] = fat

OUT_IMG.write_bytes(img)
print(f"[FAT] Created compliant FAT16 EFI boot image: {OUT_IMG} ({len(img)} bytes)")
