import os, struct

novaos = open("build/novaos.img", "rb").read()
efiboot = open("build/efiboot.img", "rb").read()

mbr_head = bytearray(novaos[:446])
mbr_tail = bytearray(novaos[512:1024*512])

part1 = bytearray(16)
part1[0] = 0x80 # Bootable
part1[1] = 0x01 # Start CHS
part1[2] = 0x01
part1[3] = 0x00
part1[4] = 0xEF # EFI System Partition
part1[5] = 0x0F # End CHS
part1[6] = 0x3F
part1[7] = 0x00
struct.pack_into("<I", part1, 8, 2048)
struct.pack_into("<I", part1, 12, len(efiboot) // 512)

mbr_table = part1 + bytearray(16*3)
full_mbr = mbr_head + mbr_table + bytearray([0x55, 0xAA]) + mbr_tail

esp_start = 2048 * 512
total_size = 128 * 1024 * 1024 # 128 MB Target Disk
disk_data = bytearray(total_size)
disk_data[:len(full_mbr)] = full_mbr

# Embed real YouTube thumbnail assets in free MBR sectors (LBA 1024..1600)
def embed_asset(lba, filename):
    path = os.path.join("build", "thumbs", filename)
    if os.path.exists(path):
        data = open(path, "rb").read()
        offset = lba * 512
        disk_data[offset:offset+len(data)] = data
        print(f"[DISK EMBED] Embedded {filename} ({len(data)} bytes) at LBA {lba}")

embed_asset(1024, "yt_0_80x45.bin")
embed_asset(1060, "yt_1_80x45.bin")
embed_asset(1100, "yt_2_80x45.bin")
embed_asset(1150, "yt_0_160x90.bin")
embed_asset(1300, "yt_1_160x90.bin")
embed_asset(1450, "yt_2_160x90.bin")

disk_data[esp_start:esp_start+len(efiboot)] = efiboot

# Embed Full-Length Real 576x432 YUV420P Video + 48kHz Stereo PCM Audio for Video 1
pcm_path = os.path.join("build", "media_cache", "yt0_48k.pcm")
if os.path.exists(pcm_path):
    pcm_raw = open(pcm_path, "rb").read()
    pcm_target_len = 3648000  # 19.00s @ 48kHz 16-bit stereo (7125 exact sectors)
    pcm_padded = pcm_raw[:pcm_target_len].ljust(pcm_target_len, b"\x00")
    off = 10000 * 512
    disk_data[off:off+len(pcm_padded)] = pcm_padded
    print(f"[DISK EMBED] Embedded yt0_48k.pcm ({len(pcm_padded)} bytes) at LBA 10000")

yuv_path = os.path.join("build", "media_cache", "yt0_320x240.yuv")
if os.path.exists(yuv_path):
    yuv_raw = open(yuv_path, "rb").read()
    off = 18000 * 512
    assert off + len(yuv_raw) <= total_size, f"Video exceeds 128MB disk! {off + len(yuv_raw)}"
    disk_data[off:off+len(yuv_raw)] = yuv_raw
    print(f"[DISK EMBED] Embedded yt0_320x240.yuv ({len(yuv_raw)} bytes, {len(yuv_raw)//115200} frames) at LBA 18000")

with open("build/target_disk.raw", "wb") as f:
    f.write(disk_data)
print("target_disk.raw built:", len(disk_data), "bytes")
