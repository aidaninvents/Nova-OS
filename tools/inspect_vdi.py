import struct

vdi_path = "/mnt/c/Users/aidan/VirtualBox VMs/Nova OS/Nova OS_1.vdi"
with open(vdi_path, "rb") as f:
    hdr = f.read(512)

magic = hdr[0x40:0x44]
print("Magic:", magic)
off_blocks, off_data, n_blocks, n_blocks_alloc, block_size, extra, disk_size = struct.unpack_from("<IIIIIIQ", hdr, 0x154)
print(f"off_blocks=0x{off_blocks:x}, off_data=0x{off_data:x}, n_blocks={n_blocks}, n_blocks_alloc={n_blocks_alloc}, block_size=0x{block_size:x}, disk_size={disk_size}")
