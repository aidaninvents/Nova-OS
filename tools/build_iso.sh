#!/bin/bash
# tools/build_iso.sh
# Assembles the NovaOS BIOS Installer ISO using ISOLINUX and xorriso

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ISO_ROOT="$ROOT_DIR/build/iso_root"
ISO_OUTPUT="$ROOT_DIR/build/NovaOS-Installer.iso"
KVER="7.0.0-38-generic"

echo "[ISO] Preparing ISO staging directory at $ISO_ROOT..."
rm -rf "$ISO_ROOT"
mkdir -p "$ISO_ROOT/boot/isolinux"

# Ensure NovaOS disk image is built
if [ ! -f "$ROOT_DIR/build/novaos.img" ]; then
    echo "[ISO] building novaos.img first..."
    make -C "$ROOT_DIR" build/novaos.img
fi

# Ensure installer initramfs is built
if [ ! -f "$ROOT_DIR/build/initramfs.cpio.gz" ]; then
    echo "[ISO] building initramfs.cpio.gz..."
    "$ROOT_DIR/tools/build_initramfs.sh"
fi

echo "[ISO] Copying bootloader and menu files..."
# Copy ISOLINUX binaries
cp /usr/lib/ISOLINUX/isolinux.bin "$ISO_ROOT/boot/isolinux/"
cp /usr/lib/syslinux/modules/bios/ldlinux.c32 "$ISO_ROOT/boot/isolinux/"
cp /usr/lib/syslinux/modules/bios/menu.c32 "$ISO_ROOT/boot/isolinux/"
cp /usr/lib/syslinux/modules/bios/libutil.c32 "$ISO_ROOT/boot/isolinux/"
cp /usr/lib/syslinux/modules/bios/libcom32.c32 "$ISO_ROOT/boot/isolinux/"
cp /usr/lib/syslinux/modules/bios/chain.c32 "$ISO_ROOT/boot/isolinux/"
cp /usr/lib/syslinux/modules/bios/reboot.c32 "$ISO_ROOT/boot/isolinux/"
cp /usr/lib/syslinux/modules/bios/poweroff.c32 "$ISO_ROOT/boot/isolinux/"
cp /usr/lib/syslinux/memdisk "$ISO_ROOT/boot/isolinux/memdisk"

# Copy ISOLINUX configuration
cp "$ROOT_DIR/installer/isolinux/isolinux.cfg" "$ISO_ROOT/boot/isolinux/"

echo "[ISO] Copying kernel, initramfs, and OS image..."
cp "/boot/vmlinuz-$KVER" "$ISO_ROOT/boot/vmlinuz"
chmod 644 "$ISO_ROOT/boot/vmlinuz"
cp "$ROOT_DIR/build/initramfs.cpio.gz" "$ISO_ROOT/boot/initramfs.cpio.gz"
cp "$ROOT_DIR/build/novaos.img" "$ISO_ROOT/boot/novaos.img"
cp "$ROOT_DIR/build/novaos.img" "$ISO_ROOT/novaos.img"

# Generate and bundle .nosp binaries on the ISO
if [ -f "$ROOT_DIR/tools/make_nosp.py" ]; then
    python3 "$ROOT_DIR/tools/make_nosp.py" "$ROOT_DIR/build"
    cp "$ROOT_DIR/build/startup.nosp" "$ISO_ROOT/startup.nosp"
    cp "$ROOT_DIR/build/startup.nosp" "$ISO_ROOT/boot/startup.nosp"
    cp "$ROOT_DIR/build/wifi.nosp" "$ISO_ROOT/wifi.nosp"
    cp "$ROOT_DIR/build/wifi.nosp" "$ISO_ROOT/boot/wifi.nosp"
    cp "$ROOT_DIR/build/chrome.nosp" "$ISO_ROOT/chrome.nosp"
    cp "$ROOT_DIR/build/chrome.nosp" "$ISO_ROOT/boot/chrome.nosp"
    cp "$ROOT_DIR/build/shop.nosp" "$ISO_ROOT/shop.nosp"
    cp "$ROOT_DIR/build/shop.nosp" "$ISO_ROOT/boot/shop.nosp"
    cp "$ROOT_DIR/build/youtube.nosp" "$ISO_ROOT/youtube.nosp"
    cp "$ROOT_DIR/build/youtube.nosp" "$ISO_ROOT/boot/youtube.nosp"
    cp "$ROOT_DIR/build/java.nosp" "$ISO_ROOT/java.nosp"
    cp "$ROOT_DIR/build/java.nosp" "$ISO_ROOT/boot/java.nosp"
    cp "$ROOT_DIR/build/html.nosp" "$ISO_ROOT/html.nosp"
    cp "$ROOT_DIR/build/html.nosp" "$ISO_ROOT/boot/html.nosp"
fi

cp "$ROOT_DIR/installer/isolinux/isolinux.cfg" "$ISO_ROOT/isolinux.cfg"
# Also place at root of CD for direct lookup
# Build EFI bootloader and EFI system partition image if available
if [ -f "$ROOT_DIR/tools/build_efi.py" ]; then
    python3 "$ROOT_DIR/tools/build_efi.py" 2>/dev/null || true
    python3 "$ROOT_DIR/tools/make_efiboot.py" 2>/dev/null || true
fi

echo "[ISO] Copying EFI boot files..."
mkdir -p "$ISO_ROOT/EFI/BOOT" "$ISO_ROOT/EFI/NOVA"
[ -f "$ROOT_DIR/build/BOOTX64.EFI" ] && cp "$ROOT_DIR/build/BOOTX64.EFI" "$ISO_ROOT/EFI/BOOT/BOOTX64.EFI"
[ -f "$ROOT_DIR/build/kernel.bin" ] && cp "$ROOT_DIR/build/kernel.bin" "$ISO_ROOT/EFI/NOVA/KERNEL.BIN"
[ -f "$ROOT_DIR/build/fs.bin" ] && cp "$ROOT_DIR/build/fs.bin" "$ISO_ROOT/EFI/NOVA/NOVAFS.BIN"
[ -f "$ROOT_DIR/build/efiboot.img" ] && cp "$ROOT_DIR/build/efiboot.img" "$ISO_ROOT/boot/efiboot.img" && cp "$ROOT_DIR/build/efiboot.img" "$ISO_ROOT/efiboot.img"

echo "[ISO] Generating bootable dual BIOS+UEFI ISO with xorriso..."
if [ -f "$ISO_ROOT/boot/efiboot.img" ]; then
    xorriso -as mkisofs \
        -iso-level 3 \
        -full-iso9660-filenames \
        -volid "NOVAOS_INST" \
        -b boot/isolinux/isolinux.bin \
        -c boot/isolinux/boot.cat \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        -eltorito-alt-boot \
        -e boot/efiboot.img \
        -no-emul-boot \
        -isohybrid-gpt-basdat \
        -output "$ISO_OUTPUT" \
        "$ISO_ROOT"
else
    xorriso -as mkisofs \
        -iso-level 3 \
        -full-iso9660-filenames \
        -volid "NOVAOS_INST" \
        -b boot/isolinux/isolinux.bin \
        -c boot/isolinux/boot.cat \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        -output "$ISO_OUTPUT" \
        "$ISO_ROOT"
fi

echo "[ISO] Successfully built: $ISO_OUTPUT"
echo "[ISO] ISO size: $(stat -c%s "$ISO_OUTPUT") bytes"
