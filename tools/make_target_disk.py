#!/usr/bin/env python3
"""Build target disk image with dual BIOS + UEFI partitioning."""
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / "build"
NOVAOS = BUILD / "novaos.img"
EFIBOOT = BUILD / "efiboot.img"
OUT_RAW = BUILD / "target_disk.raw"

DISK_SIZE = 32 * 1024 * 1024  # 32 MiB
raw = bytearray(DISK_SIZE)

# 1. BIOS payload (LBA 0..1023)
bios_data = NOVAOS.read_bytes()
raw[0:len(bios_data)] = bios_data

# 2. ESP payload (LBA 2048..7807)
esp_data = EFIBOOT.read_bytes()
esp_offset = 2048 * 512
raw[esp_offset:esp_offset + len(esp_data)] = esp_data

# 3. MBR Partition Entry 1 at offset 446
# Status: 0x80 (Bootable), Type: 0xEF (ESP), Start LBA: 2048, Count: 5760
part_entry = b'\x80\x00\x02\x00\xef\xfe\xff\xff\x00\x08\x00\x00\x80\x16\x00\x00'
raw[446:462] = part_entry
raw[510:512] = b'\x55\xaa'

OUT_RAW.write_bytes(raw)
print(f"[DISK] Created dual boot disk raw image: {OUT_RAW} ({len(raw)} bytes)")
