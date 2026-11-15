import struct
from pathlib import Path

SECTOR_SIZE = 512
FS_MAGIC = b"NVFS"
VERSION = 1

ROOT = Path(__file__).resolve().parent.parent
FONT_DIR = ROOT / "fonts"
OUTPUT = ROOT / "fs" / "novafs.img"

files = []

logo_path = ROOT / "boot image" / "nova_logo.raw"

if logo_path.exists():
    files.append(
        (
            "NOVALOGO.RAW",
            logo_path.read_bytes()
        )
    )
audio_path = ROOT / "audio" / "startup.wav"

if audio_path.exists():
    files.append(("STARTUP.WAV", audio_path.read_bytes()))
bitmap_paths = sorted(
    list(FONT_DIR.glob("*.FNT")),
    key=lambda path: path.name.upper()
)

for path in bitmap_paths:

    destination = path.name.upper()

    files.append(
        (destination, path.read_bytes())
    )

for idx in range(3):
    th_path = ROOT / "build" / "thumbs" / f"yt_{idx}_80x45.bin"
    if th_path.exists():
        files.append((f"YT{idx}.RAW", th_path.read_bytes()))


# ------------------------------------------------------------
# Build NovaFS.
# ------------------------------------------------------------

OUTPUT.parent.mkdir(parents=True, exist_ok=True)

directory_sector = bytearray(SECTOR_SIZE)
data = bytearray()

entry_size = 32
first_data_sector = 2


for index, (name, contents) in enumerate(files):

    name_bytes = (
        name.encode("ascii")[:12]
        .ljust(12, b"\0")
    )

    size = len(contents)

    start_sector = (
        first_data_sector
        + len(data) // SECTOR_SIZE
    )

    entry = struct.pack(
        "<12sII",
        name_bytes,
        start_sector,
        size,
    ).ljust(
        entry_size,
        b"\0"
    )

    offset = index * entry_size

    directory_sector[
        offset:offset + entry_size
    ] = entry

    data.extend(contents)

    data.extend(
        b"\0" * ((-len(data)) % SECTOR_SIZE)
    )


# ------------------------------------------------------------
# NovaFS header.
# ------------------------------------------------------------

header = bytearray(SECTOR_SIZE)

struct.pack_into(
    "<4sHHII",
    header,
    0,
    FS_MAGIC,
    VERSION,
    entry_size,
    len(files),
    first_data_sector,
)


# ------------------------------------------------------------
# Final filesystem image.
# ------------------------------------------------------------

image = (
    header
    + directory_sector
    + data
)

image.extend(
    b"\0" * ((-len(image)) % SECTOR_SIZE)
)

OUTPUT.write_bytes(image)


# ------------------------------------------------------------
# Report.
# ------------------------------------------------------------

print(f"Created: {OUTPUT}")
print(f"Files: {len(files)}")
print(f"Image size: {len(image)} bytes")
print()

for name, contents in files:
    print(
        f"  {name:12} "
        f"{len(contents):8} bytes"
    )
