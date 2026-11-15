import struct

data = open("build/efiboot.img", "rb").read()
sec_size, spc, rsvd, nfats, r_ents, tot_sec, mdesc, fat_sec = struct.unpack_from("<HBHBHHBH", data, 11)
root_start = (rsvd + nfats * fat_sec) * sec_size
print(f"SecSize={sec_size}, SPC={spc}, Rsvd={rsvd}, FATS={nfats}, RootStart={root_start}")
for i in range(16):
    ent = data[root_start + i*32 : root_start + (i+1)*32]
    name = ent[0:11]
    attr = ent[11]
    clust, size = struct.unpack_from("<HI", ent, 26)
    if name[0] != 0:
        print(f"Root Entry {i}: Name={repr(name)}, Attr={hex(attr)}, Clust={clust}, Size={size}")

# Check /EFI directory
efi_clust = struct.unpack_from("<HI", data[root_start:root_start+32], 26)[0]
data_start = (rsvd + nfats * fat_sec + (r_ents * 32 + sec_size - 1) // sec_size) * sec_size
efi_off = data_start + (efi_clust - 2) * sec_size * spc
print(f"EFI dir offset={efi_off}")
for i in range(8):
    ent = data[efi_off + i*32 : efi_off + (i+1)*32]
    name = ent[0:11]
    attr = ent[11]
    clust, size = struct.unpack_from("<HI", ent, 26)
    if name[0] != 0:
        print(f"/EFI Entry {i}: Name={repr(name)}, Attr={hex(attr)}, Clust={clust}, Size={size}")
