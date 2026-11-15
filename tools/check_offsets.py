import os, glob

# Search for efi headers
for root in ["/usr/include", "/usr/local/include"]:
    for f in glob.glob(root + "/**/efi*.h", recursive=True):
        if "efiapi" in f or "efiboot" in f or "efidef" in f:
            print("Found:", f)

# Let's check EFI_BOOT_SERVICES struct if present
for h in ["/usr/include/efi/efiapi.h"]:
    if os.path.exists(h):
        lines = open(h).readlines()
        in_bs = False
        idx = 0
        for line in lines:
            if "struct _EFI_BOOT_SERVICES {" in line or "typedef struct _EFI_BOOT_SERVICES" in line:
                in_bs = True
                print("--- EFI_BOOT_SERVICES ---")
            if in_bs:
                line_s = line.strip()
                if line_s.endswith(";"):
                    print(f"[{idx*8:3d}] {line_s}")
                    idx += 1
                if "}" in line:
                    break
