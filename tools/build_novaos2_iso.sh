#!/bin/bash
set -euo pipefail

ROOTFS="/opt/novaos2_rootfs"
ISODIR="/opt/novaos2_iso"
SRC_NOVA2="/mnt/c/Users/aidan/Downloads/NovaOS_fixed/NovaOS_fixed/novaos2"
OUT_DIR="/mnt/c/Users/aidan/Downloads/NovaOS_fixed/NovaOS_fixed/build"
TARGETS=("$@")
if [ ${#TARGETS[@]} -eq 0 ]; then
  TARGETS=("MULTI" "EN" "ES" "IT")
fi

echo "[2.00-27300] Syncing updated novaos2 files & compiling novaos-desktop into $ROOTFS..."
cp -a "$SRC_NOVA2/." "$ROOTFS/opt/novaos2/"
if command -v gcc >/dev/null 2>&1 && pkg-config --exists gtk+-3.0 webkit2gtk-4.1; then
  gcc -O2 "$SRC_NOVA2/native/novaos_desktop.c" -o "$ROOTFS/usr/local/bin/novaos-desktop" \
    $(pkg-config --cflags --libs gtk+-3.0 webkit2gtk-4.1)
fi

# Enforce IPv4 preference + fast single-request DNS in rootfs
cat > "$ROOTFS/etc/gai.conf" << 'GAIEOF'
precedence ::ffff:0:0/96  100
GAIEOF
cat > "$ROOTFS/etc/resolv.conf" << 'DNSEOF'
options timeout:1 attempts:2 rotate single-request-reopen
nameserver 1.1.1.1
nameserver 8.8.8.8
nameserver 10.0.2.3
DNSEOF

# Pre-build linker and fontconfig caches so live boot never stalls scanning fonts/libs
chroot "$ROOTFS" ldconfig 2>/dev/null || true
chroot "$ROOTFS" fc-cache -f 2>/dev/null || true

# Clear transient state / preinstalled packages
rm -rf "$ROOTFS/opt/novaos2/storage/Packages/"*.NOSP 2>/dev/null || true
rm -f "$ROOTFS/opt/novaos2/system_state.json" 2>/dev/null || true
rm -f "$ROOTFS/etc/novaos_installed.json" 2>/dev/null || true

# Clean unused apt caches and temp bloat from rootfs (~500 MB savings!)
rm -rf "$ROOTFS/var/cache/apt/archives/"*.deb "$ROOTFS/var/cache/apt/"*.bin 2>/dev/null || true
rm -rf "$ROOTFS/var/lib/apt/lists/"* 2>/dev/null || true
rm -rf "$ROOTFS/tmp/"* 2>/dev/null || true

# Ensure kernel & initrd exist in /boot for disk installs
cp -f "$ISODIR/live/vmlinuz" "$ROOTFS/boot/vmlinuz-novaos" 2>/dev/null || true
cp -f "$ISODIR/live/initrd.img" "$ROOTFS/boot/initrd-novaos.img" 2>/dev/null || true

# Installer backend with dynamic SquashFS uncompressed size calculation (fixes 82% stall!)
mkdir -p "$ROOTFS/usr/local/sbin"
cat > "$ROOTFS/usr/local/sbin/novaos-install-disk" << 'EOF'
#!/bin/bash
set -euo pipefail
DISK="${1:-/dev/sda}"
EDITION="${2:-Pro}"
LANG="${3:-en-US}"
PKEY="${4:-}"
STATUS="/tmp/novaos_install_status.json"

set_status() {
  printf '{"running":true,"percent":%d,"stage":"%s","done":false}\n' "$1" "$2" > "$STATUS"
}

set_status 5 "Partitioning $DISK..."
umount -R /mnt/target 2>/dev/null || true
PART_PREFIX="$DISK"
case "$DISK" in
  *nvme*|*mmcblk*) PART_PREFIX="${DISK}p" ;;
esac

IS_EFI=0
[ -d /sys/firmware/efi ] && IS_EFI=1

if [ "$IS_EFI" -eq 1 ]; then
  parted -s "$DISK" mklabel gpt
  parted -s "$DISK" mkpart ESP fat32 1MiB 257MiB
  parted -s "$DISK" set 1 esp on
  parted -s "$DISK" mkpart primary ext4 257MiB 100%
  partprobe "$DISK" 2>/dev/null || true
  sleep 2
  P_EFI="${PART_PREFIX}1"
  P_ROOT="${PART_PREFIX}2"
  set_status 12 "Formatting EFI ($P_EFI) and Root ($P_ROOT)..."
  mkfs.vfat -F32 "$P_EFI" >/dev/null 2>&1
  mkfs.ext4 -F -L NovaOS "$P_ROOT" >/dev/null 2>&1
  mkdir -p /mnt/target
  mount -o noatime,nodiratime,barrier=0,commit=60 "$P_ROOT" /mnt/target
  mkdir -p /mnt/target/boot/efi
  mount "$P_EFI" /mnt/target/boot/efi
else
  parted -s "$DISK" mklabel msdos
  parted -s "$DISK" mkpart primary ext4 1MiB 100%
  parted -s "$DISK" set 1 boot on
  partprobe "$DISK" 2>/dev/null || true
  sleep 2
  P_ROOT="${PART_PREFIX}1"
  set_status 12 "Formatting Root ($P_ROOT)..."
  mkfs.ext4 -F -L NovaOS "$P_ROOT" >/dev/null 2>&1
  mkdir -p /mnt/target
  mount -o noatime,nodiratime,barrier=0,commit=60 "$P_ROOT" /mnt/target
fi

set_status 22 "Copying Nova OS 2.00 Beta 4 (27300) files to disk..."
SQFS=""
for cand in /run/live/medium/live/filesystem.squashfs /lib/live/mount/medium/live/filesystem.squashfs; do
  [ -f "$cand" ] && SQFS="$cand" && break
done
if [ -z "$SQFS" ]; then
  mkdir -p /mnt/iso
  for cddev in /dev/sr0 /dev/cdrom /dev/sr1; do
    if [ -b "$cddev" ] && mount -o ro "$cddev" /mnt/iso 2>/dev/null; then
      [ -f /mnt/iso/live/filesystem.squashfs ] && SQFS="/mnt/iso/live/filesystem.squashfs" && break
      umount /mnt/iso 2>/dev/null || true
    fi
  done
fi

TOTAL_EST=2500000000
if [ -n "$SQFS" ]; then
  SQ_KB=$(unsquashfs -s "$SQFS" 2>/dev/null | awk '/Filesystem size/{print int($3)}')
  if [ -n "$SQ_KB" ] && [ "$SQ_KB" -gt 100000 ]; then
    TOTAL_EST=$((SQ_KB * 1024))
  fi
  unsquashfs -f -d /mnt/target "$SQFS" >/dev/null 2>&1 &
else
  rsync -a --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*"} / /mnt/target/ >/dev/null 2>&1 &
fi
UPID=$!
while kill -0 "$UPID" 2>/dev/null; do
  USED=$(df -B1 --output=used /mnt/target 2>/dev/null | tail -n 1 | tr -dc '0-9')
  [ -z "$USED" ] && USED=0
  PCT=$((22 + (USED * 66 / TOTAL_EST)))
  [ "$PCT" -lt 22 ] && PCT=22
  [ "$PCT" -gt 88 ] && PCT=88
  set_status "$PCT" "Getting files ready for installation ($PCT%)..."
  sleep 2
done
wait "$UPID"
umount /mnt/iso 2>/dev/null || true

set_status 89 "Configuring Edition ($EDITION), Language ($LANG), and Fonts..."
cat > /mnt/target/etc/novaos_installed.json << META
{
  "edition": "$EDITION",
  "language": "$LANG",
  "product_key": "$PKEY",
  "installed": true
}
META

set_status 92 "Installing GRUB Bootloader on $DISK..."
mkdir -p /mnt/target/dev /mnt/target/proc /mnt/target/sys /mnt/target/boot/grub
mount --bind /dev /mnt/target/dev
mount --bind /proc /mnt/target/proc
mount --bind /sys /mnt/target/sys

if [ "$IS_EFI" -eq 1 ]; then
  grub-install --target=x86_64-efi --efi-directory=/mnt/target/boot/efi --boot-directory=/mnt/target/boot --removable --no-nvram >/tmp/novaos_grub.log 2>&1 || true
else
  grub-install --target=i386-pc --boot-directory=/mnt/target/boot "$DISK" >/tmp/novaos_grub.log 2>&1 || true
fi

ROOT_UUID=$(blkid -s UUID -o value "$P_ROOT")
cat > /mnt/target/boot/grub/grub.cfg << GRUBCFG
set timeout=0
set default=0

menuentry "Nova OS 2.00 $EDITION (Build 27300 - 1080p)" {
    search --no-floppy --fs-uuid --set=root $ROOT_UUID
    linux /boot/vmlinuz-novaos root=UUID=$ROOT_UUID rw quiet loglevel=0 ipv6.disable=1 modprobe.blacklist=floppy
    initrd /boot/initrd-novaos.img
}
GRUBCFG

umount /mnt/target/sys /mnt/target/proc /mnt/target/dev 2>/dev/null || true
sync
umount /mnt/target/boot/efi 2>/dev/null || true
umount /mnt/target 2>/dev/null || true

printf '{"running":false,"percent":100,"stage":"Installation complete! Ready to boot from %s.","done":true}\n' "$DISK" > "$STATUS"
EOF
sed -i 's/\r$//' "$ROOTFS/usr/local/sbin/novaos-install-disk"
chmod +x "$ROOTFS/usr/local/sbin/novaos-install-disk"

# Parallelized /sbin/init for rapid boot into Setup on 4 GB RAM + 1 GB zram swap
cat > "$ROOTFS/sbin/init" << 'EOF'
#!/bin/sh
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export HOME=/root
export TERM=linux
export TZ=America/Chicago
export MALLOC_ARENA_MAX=2

mount -t proc proc /proc 2>/dev/null || true
mount -t sysfs sysfs /sys 2>/dev/null || true
mount -t devtmpfs devtmpfs /dev 2>/dev/null || true
mkdir -p /dev/pts /dev/shm /run /run/dbus /tmp
mount -t devpts devpts /dev/pts 2>/dev/null || true
mount -t tmpfs -o size=256M tmpfs /dev/shm 2>/dev/null || true
mount -t tmpfs -o size=256M tmpfs /tmp 2>/dev/null || true
mount -t tmpfs -o size=128M tmpfs /run 2>/dev/null || true

mount -o remount,rw / 2>/dev/null || true

# Disable IPv6 in runtime sysctl too so browsers never hang on AAAA/fec0:: sockets
sysctl -w net.ipv6.conf.all.disable_ipv6=1 net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1 || true

# Write fast DNS resolvers upfront before server/browser starts
rm -f /etc/resolv.conf 2>/dev/null || true
printf "options timeout:1 attempts:2 rotate single-request-reopen\nnameserver 1.1.1.1\nnameserver 8.8.8.8\nnameserver 10.0.2.3\n" > /etc/resolv.conf 2>/dev/null || true

# Start Nova OS backend server immediately in parallel with hardware probe & Xorg
python3 /opt/novaos2/server.py >/tmp/novaos2_srv.log 2>&1 &

# Enable 1 GB zram compressed swap so low-RAM hosts never thrash SquashFS/WebKit page cache
modprobe zram 2>/dev/null || true
if [ -b /dev/zram0 ]; then
  echo lz4 > /sys/block/zram0/comp_algorithm 2>/dev/null || echo zstd > /sys/block/zram0/comp_algorithm 2>/dev/null || true
  echo 1073741824 > /sys/block/zram0/disksize 2>/dev/null || true
  mkswap /dev/zram0 >/dev/null 2>&1 && swapon -p 100 /dev/zram0 2>/dev/null || true
fi
sysctl -w vm.swappiness=60 >/dev/null 2>&1 || true

echo "[NovaOS 2.00 Beta 4 - 27300] Starting udev & drivers..." >/tmp/novaos2_boot.log 2>/dev/null || true
/lib/systemd/systemd-udevd --daemon 2>/dev/null || /usr/lib/systemd/systemd-udevd --daemon 2>/dev/null || true
udevadm trigger --action=add 2>/dev/null || true
udevadm settle --timeout=2 2>/dev/null || true
for m in evdev psmouse bochs vboxvideo vboxguest e1000 e1000e r8169 ahci nvme sd_mod snd_hda_intel snd_intel8x0; do
  modprobe "$m" 2>/dev/null || true
done
dbus-daemon --system --fork 2>/dev/null || true

# Bring up Ethernet cleanly (instant IPv4 link + DHCP without blocking resolv.conf)
(
  ip link set lo up 2>/dev/null || true
  for iface in /sys/class/net/*; do
    name=$(basename "$iface")
    [ "$name" = "lo" ] && continue
    ip link set "$name" up 2>/dev/null || true
    dhcpcd -4 --nohook resolv.conf -b "$name" >/dev/null 2>&1 || true
    sleep 0.6
    if ! ip -4 route show default 2>/dev/null | grep -q default; then
      ip addr add 10.0.2.15/24 dev "$name" 2>/dev/null || true
      ip route add default via 10.0.2.2 dev "$name" 2>/dev/null || true
    fi
  done
) &

# Start Xorg while async DHCP completes
export DISPLAY=:0
Xorg :0 -nolisten tcp vt1 >/tmp/xorg.log 2>&1 &

for i in $(seq 1 200); do
  [ -S /tmp/.X11-unix/X0 ] && break
  sleep 0.1
done

echo "[NovaOS 2.00 Beta 4 - 27300] Launching Desktop & Setup..." >/tmp/novaos2_boot.log 2>/dev/null || true
/root/.xinitrc >/tmp/xinit.log 2>&1
exec /bin/sh
EOF
sed -i 's/\r$//' "$ROOTFS/sbin/init"
chmod +x "$ROOTFS/sbin/init"

# Fast .xinitrc: log load events to ttyS0, IPv4/fast DNS env, keep WebKit compositing active
cat > "$ROOTFS/root/.xinitrc" << 'EOF'
#!/bin/bash
echo "[XINIT] Starting NovaOS 2.00 Beta 4 X11 session..."
xset s off -dpms s noblank
(pulseaudio --start --exit-idle-time=-1 >/dev/null 2>&1 || true) &

export MALLOC_ARENA_MAX=2
export G_ENABLE_DIAGNOSTIC=0
export GIO_USE_VFS=local
export RES_OPTIONS="timeout:1 attempts:2 rotate single-request-reopen"
export WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1
if [ ! -e /dev/dri/renderD128 ]; then
  export WEBKIT_DISABLE_DMABUF_RENDERER=1
fi

OUT=$(xrandr | awk '/ connected/{print $1; exit}')
if ! xrandr -s 1920x1080 2>/dev/null; then
  MODELINE=$(cvt 1920 1080 60 | awk '/Modeline/{sub(/^Modeline /,""); print}')
  MODENAME=$(echo "$MODELINE" | awk '{print $1}')
  eval xrandr --newmode $MODELINE 2>/dev/null || true
  xrandr --addmode "$OUT" "$MODENAME" 2>/dev/null || true
  xrandr --output "$OUT" --mode "$MODENAME" 2>/dev/null || true
fi

openbox &
sleep 0.4
for i in $(seq 1 100); do
  if python3 -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8090/api/sysinfo', timeout=1)" 2>/dev/null; then
    break
  fi
  sleep 0.1
done
echo "[XINIT] Server ready, launching novaos-desktop..."
exec /usr/local/bin/novaos-desktop http://127.0.0.1:8090/ 2>&1
EOF
sed -i 's/\r$//' "$ROOTFS/root/.xinitrc"
chmod +x "$ROOTFS/root/.xinitrc"

build_one_iso() {
  local SHORT="$1"
  local LANG_CODE LOC_PREFIX OUT_TAG
  case "$SHORT" in
    MULTI) LANG_CODE="en-US"; LOC_PREFIX="multi"; OUT_TAG="MultiLang" ;;
    EN) LANG_CODE="en-US"; LOC_PREFIX="en"; OUT_TAG="EN" ;;
    ES) LANG_CODE="es-ES"; LOC_PREFIX="es"; OUT_TAG="ES" ;;
    IT) LANG_CODE="it-IT"; LOC_PREFIX="it"; OUT_TAG="IT" ;;
    *) echo "Unknown language code: $SHORT" >&2; exit 1 ;;
  esac

  local TMP_ISO="/opt/NovaOS-2.00-Beta4-27300-${OUT_TAG}.iso"
  local OUT_ISO="$OUT_DIR/NovaOS-2.00-Beta4-27300-${OUT_TAG}.iso"

  local DISC_KEY
  DISC_KEY=$(python3 -c '
import random, string
def grp(): return "".join(random.choices(string.ascii_uppercase + string.digits, k=5))
print(f"NOVA2-{grp()}-{grp()}-{grp()}-{grp()}")
')
  echo "$LANG_CODE" > "$ROOTFS/etc/novaos_iso_lang"
  echo "$DISC_KEY" > "$ROOTFS/etc/novaos_disc_key"
  echo "[2.00-27300 $OUT_TAG] Language=$LANG_CODE Disc key=$DISC_KEY"

  # Fast GRUB boot (0s timeout, IPv4 only, skip persistence scans; floppy probed async in background)
  cat > "$ISODIR/boot/grub/grub.cfg" << EOF
set timeout=0
set default=0

menuentry "Nova OS 2.00 Beta 4 (Build 27300 - $OUT_TAG 1080p Live / Installer)" {
    linux /live/vmlinuz boot=live nopersistence noprompt noeject quickreboot quiet loglevel=0 ipv6.disable=1 modprobe.blacklist=floppy
    initrd /live/initrd.img
}
EOF
  sed -i 's/\r$//' "$ISODIR/boot/grub/grub.cfg"

  # Exclude unused locales, docs, manpages, info, and apt caches for smaller & faster SquashFS
  local EXFILE="/tmp/sqfs_exclude_27300_${OUT_TAG}.txt"
  cat > "$EXFILE" << 'EXBASE'
usr/share/doc
usr/share/man
usr/share/info
var/cache/apt
var/lib/apt/lists
EXBASE
  for d in "$ROOTFS/usr/share/locale/"*; do
    [ -d "$d" ] || continue
    b=$(basename "$d")
    if [ "$LOC_PREFIX" = "multi" ]; then
      case "$b" in
        en*|es*|it*|fr*|de*|ja*) ;;
        *) echo "usr/share/locale/$b" >> "$EXFILE" ;;
      esac
    else
      case "$b" in
        en*|en_US|${LOC_PREFIX}*) ;;
        *) echo "usr/share/locale/$b" >> "$EXFILE" ;;
      esac
    fi
  done

  echo "[2.00-27300 $OUT_TAG] Building fast zstd-1 SquashFS image..."
  mksquashfs "$ROOTFS" "$ISODIR/live/filesystem.squashfs" -comp zstd -Xcompression-level 1 -b 262144 -processors 16 -noappend -ef "$EXFILE"

  echo "[2.00-27300 $OUT_TAG] Building bootable ISO: $TMP_ISO..."
  grub-mkrescue -o "$TMP_ISO" "$ISODIR"
  mkdir -p "$OUT_DIR"
  sync
  echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
  rm -f "$OUT_ISO"
  dd if="$TMP_ISO" of="$OUT_ISO" bs=4M status=none
  sync
  ls -lh "$TMP_ISO" "$OUT_ISO"
}

for tgt in "${TARGETS[@]}"; do
  build_one_iso "$tgt"
done
