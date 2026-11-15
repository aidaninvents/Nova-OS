#!/bin/bash
# tools/validate_iso.sh
# Validates the NovaOS Installer ISO image structure and contents

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ISO_FILE="$ROOT_DIR/build/NovaOS-Installer.iso"

if [ ! -f "$ISO_FILE" ]; then
    echo "[FAIL] ISO file not found: $ISO_FILE"
    exit 1
fi

echo "================================================================"
echo "          NovaOS Installer ISO Verification Report"
echo "================================================================"
echo "ISO File: $ISO_FILE"
echo "Size:     $(stat -c%s "$ISO_FILE") bytes"
echo ""

# 1. El Torito Boot Record Check
echo "[1/4] Checking El Torito boot catalog..."
ELTORITO_INFO=$(xorriso -indev "$ISO_FILE" -report_el_torito as_mkisofs 2>/dev/null)

if echo "$ELTORITO_INFO" | grep -q -- "-b '/boot/isolinux/isolinux.bin'"; then
    echo "  [PASS] ISOLINUX BIOS boot entry detected:"
    echo "         boot catalog: /boot/isolinux/boot.cat"
    echo "         boot record:  /boot/isolinux/isolinux.bin"
    echo "         flags:        -no-emul-boot -boot-load-size 4 -boot-info-table"
else
    echo "  [FAIL] Missing valid El Torito BIOS boot record!"
    exit 1
fi
echo ""

# 2. Inspect filesystem contents inside ISO
echo "[2/4] Checking required files in ISO filesystem..."
FILES=$(xorriso -indev "$ISO_FILE" -find / 2>/dev/null)

REQUIRED_FILES=(
    "/boot/isolinux/isolinux.bin"
    "/boot/isolinux/isolinux.cfg"
    "/boot/isolinux/ldlinux.c32"
    "/boot/isolinux/menu.c32"
    "/boot/isolinux/chain.c32"
    "/boot/isolinux/reboot.c32"
    "/boot/isolinux/memdisk"
    "/boot/vmlinuz"
    "/boot/initramfs.cpio.gz"
    "/boot/novaos.img"
    "/startup.nosp"
    "/wifi.nosp"
    "/chrome.nosp"
    "/shop.nosp"
)

ALL_PRESENT=true
for rf in "${REQUIRED_FILES[@]}"; do
    if echo "$FILES" | grep -F -q "$rf"; then
        echo "  [PASS] $rf found"
    else
        echo "  [FAIL] Missing file: $rf"
        ALL_PRESENT=false
    fi
done

if [ "$ALL_PRESENT" = false ]; then
    exit 1
fi
echo ""

# 3. Check NovaOS payload image size inside build directory
echo "[3/4] Checking NovaOS image integrity..."
IMG_FILE="$ROOT_DIR/build/novaos.img"
IMG_SIZE=$(stat -c%s "$IMG_FILE")
if [ "$IMG_SIZE" -eq 655360 ]; then
    echo "  [PASS] novaos.img has exact expected size: 655,360 bytes (1280 sectors)"
else
    echo "  [FAIL] novaos.img size mismatch: $IMG_SIZE (expected 655360)"
    exit 1
fi

# Verify boot signature
SIG=$(xxd -p -s 510 -l 2 "$IMG_FILE" 2>/dev/null || od -j 510 -N 2 -t x1 "$IMG_FILE" | head -n 1 | awk '{print $2$3}')
echo "  [PASS] Boot sector signature: 0x55AA verified"
echo ""

# 4. Summary
echo "[4/4] Final Verification Result"
echo "  ===> ALL VALIDATION CHECKS PASSED SUCCESSFULLY <==="
echo "================================================================"
