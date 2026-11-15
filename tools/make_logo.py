from pathlib import Path

from PIL import Image


# ============================================================
# PATHS
# ============================================================

ROOT = Path(__file__).resolve().parent.parent

SOURCE = (
    ROOT
    / "boot image"
    / "nova_logo.png"
)

OUTPUT = (
    ROOT
    / "boot image"
    / "nova_logo.raw"
)


# ============================================================
# NOVAOS LOGO SIZE
#
# The logo will be resized to 220x220.
# This leaves plenty of room for:
#
#     logo
#       |
#     spinner
#       |
# Starting NovaOS...
#
# ============================================================

LOGO_WIDTH = 220
LOGO_HEIGHT = 220


# ============================================================
# LOAD IMAGE
# ============================================================

if not SOURCE.exists():
    raise FileNotFoundError(
        f"Missing logo: {SOURCE}"
    )


image = Image.open(SOURCE).convert("RGBA")


print(
    f"Source: {image.width}x{image.height}"
)

print(
    f"Mode: {image.mode}"
)


# ============================================================
# RESIZE
#
# Keep the logo square and preserve transparency.
# ============================================================

image = image.resize(
    (
        LOGO_WIDTH,
        LOGO_HEIGHT
    ),
    Image.Resampling.LANCZOS
)


# ============================================================
# WRITE NOVAOS RAW FORMAT
#
# Each pixel:
#
#     4 bytes
#     R G B A
#
# Transparent pixels remain transparent.
# ============================================================

with open(OUTPUT, "wb") as out:

    for y in range(LOGO_HEIGHT):

        for x in range(LOGO_WIDTH):

            r, g, b, a = image.getpixel(
                (x, y)
            )

            out.write(
                bytes([
                    r,
                    g,
                    b,
                    a
                ])
            )


# ============================================================
# VERIFY SIZE
# ============================================================

expected_size = (
    LOGO_WIDTH
    * LOGO_HEIGHT
    * 4
)

actual_size = OUTPUT.stat().st_size


print()
print(
    f"Created: {OUTPUT}"
)

print(
    f"Size: {actual_size} bytes"
)

print(
    f"Expected: {expected_size} bytes"
)

if actual_size != expected_size:
    raise RuntimeError(
        "Logo size verification failed!"
    )


print()
print("NovaOS logo conversion complete.")
