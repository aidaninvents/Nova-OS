#!/bin/bash
# tools/build_initramfs.sh
# Generates a lightweight standalone initramfs with BusyBox, kmod, kernel modules,
# the installer script, and NovaOS disk image.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
INITRAMFS_WORK="$ROOT_DIR/build/initramfs_work"
OUTPUT_CPIO="$ROOT_DIR/build/initramfs.cpio.gz"
KVER="7.0.0-38-generic"

echo "[INITRAMFS] Preparing working directories..."
rm -rf "$INITRAMFS_WORK"
mkdir -p "$INITRAMFS_WORK"/{bin,sbin,usr/bin,usr/sbin,lib,lib64,usr/lib,usr/lib/x86_64-linux-gnu,proc,sys,dev,mnt,target,etc}

echo "[INITRAMFS] Installing BusyBox and standard symlinks..."
cp /bin/busybox "$INITRAMFS_WORK/bin/busybox"
chmod 755 "$INITRAMFS_WORK/bin/busybox"

# Install symlinks for busybox applets
for applet in $($INITRAMFS_WORK/bin/busybox --list); do
    if [ ! -e "$INITRAMFS_WORK/bin/$applet" ] && [ ! -e "$INITRAMFS_WORK/sbin/$applet" ]; then
        ln -s /bin/busybox "$INITRAMFS_WORK/bin/$applet"
    fi
done

echo "[INITRAMFS] Installing kmod and required libraries..."
if [ -f /bin/kmod ]; then
    cp /bin/kmod "$INITRAMFS_WORK/bin/kmod"
else
    cp /usr/bin/kmod "$INITRAMFS_WORK/bin/kmod"
fi
chmod 755 "$INITRAMFS_WORK/bin/kmod"

# Symlinks for modprobe, insmod, depmod
ln -sf /bin/kmod "$INITRAMFS_WORK/sbin/modprobe"
ln -sf /bin/kmod "$INITRAMFS_WORK/sbin/insmod"
ln -sf /bin/kmod "$INITRAMFS_WORK/sbin/depmod"

# Copy dynamic linker and runtime libraries for kmod
mkdir -p "$INITRAMFS_WORK/lib/x86_64-linux-gnu"
mkdir -p "$INITRAMFS_WORK/lib64"

cp -L /lib64/ld-linux-x86-64.so.2 "$INITRAMFS_WORK/lib64/" 2>/dev/null || true
cp -L /usr/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 "$INITRAMFS_WORK/lib/x86_64-linux-gnu/" 2>/dev/null || true
cp -L /usr/lib/x86_64-linux-gnu/libc.so.6 "$INITRAMFS_WORK/usr/lib/x86_64-linux-gnu/"
cp -L /usr/lib/x86_64-linux-gnu/libcrypto.so.3 "$INITRAMFS_WORK/usr/lib/x86_64-linux-gnu/"
cp -L /usr/lib/x86_64-linux-gnu/libz.so.1 "$INITRAMFS_WORK/usr/lib/x86_64-linux-gnu/"
cp -L /usr/lib/x86_64-linux-gnu/libzstd.so.1 "$INITRAMFS_WORK/usr/lib/x86_64-linux-gnu/"

# Provide /lib symlinks
ln -sf /usr/lib/x86_64-linux-gnu/libc.so.6 "$INITRAMFS_WORK/lib/x86_64-linux-gnu/"
ln -sf /usr/lib/x86_64-linux-gnu/libcrypto.so.3 "$INITRAMFS_WORK/lib/x86_64-linux-gnu/"
ln -sf /usr/lib/x86_64-linux-gnu/libz.so.1 "$INITRAMFS_WORK/lib/x86_64-linux-gnu/"
ln -sf /usr/lib/x86_64-linux-gnu/libzstd.so.1 "$INITRAMFS_WORK/lib/x86_64-linux-gnu/"

echo "[INITRAMFS] Installing kernel storage & filesystem modules..."
MOD_DEST="$INITRAMFS_WORK/lib/modules/$KVER"
mkdir -p "$MOD_DEST"

# Module list for disk and filesystem access
MODULES=(
    "kernel/drivers/ata/ahci.ko.zst"
    "kernel/drivers/ata/libahci.ko.zst"
    "kernel/drivers/ata/pata_oldpiix.ko.zst"
    "kernel/drivers/ata/pata_mpiix.ko.zst"
    "kernel/drivers/nvme/host/nvme.ko.zst"
    "kernel/drivers/nvme/host/nvme-core.ko.zst"
    "kernel/fs/isofs/isofs.ko.zst"
)

for m in "${MODULES[@]}"; do
    src="/lib/modules/$KVER/$m"
    if [ -f "$src" ]; then
        dst_dir="$MOD_DEST/$(dirname "$m")"
        mkdir -p "$dst_dir"
        cp "$src" "$dst_dir/"
    fi
done

# Copy module metadata
for meta in modules.dep modules.dep.bin modules.alias modules.alias.bin modules.symbols modules.symbols.bin modules.builtin modules.builtin.bin; do
    if [ -f "/lib/modules/$KVER/$meta" ]; then
        cp "/lib/modules/$KVER/$meta" "$MOD_DEST/"
    fi
done

echo "[INITRAMFS] Installing installer init script and NovaOS payload..."
cp "$ROOT_DIR/installer/init" "$INITRAMFS_WORK/init"
chmod 755 "$INITRAMFS_WORK/init"

# Include novaos.img in root of initramfs for instantaneous and fail-safe access
cp "$ROOT_DIR/build/novaos.img" "$INITRAMFS_WORK/novaos.img"
[ -f "$ROOT_DIR/build/efiboot.img" ] && cp "$ROOT_DIR/build/efiboot.img" "$INITRAMFS_WORK/efiboot.img"

echo "[INITRAMFS] Creating compressed cpio archive: $OUTPUT_CPIO..."
(
    cd "$INITRAMFS_WORK"
    find . | /bin/busybox cpio -o -H newc | gzip -1 > "$OUTPUT_CPIO"
)

echo "[INITRAMFS] Done. Size: $(stat -c%s "$OUTPUT_CPIO") bytes."
