from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

# ============================================================
# PATHS
# ============================================================

ROOT = Path(__file__).resolve().parent
FONT_DIR = ROOT / "fonts"

# ============================================================
# NORMAL NOVAOS FONT SETTINGS
# ============================================================

SPINNER_FIRST = 0xE052
SPINNER_LAST = 0xE0CB
WIDTH = 12
HEIGHT = 20
FONT_SIZE = 15
BASELINE = 15

FIRST_CHAR = 32
LAST_CHAR = 126

# ============================================================
# BOOT SPINNER SETTINGS
# ============================================================

BOOT_WIDTH = 36
BOOT_HEIGHT = 60
BOOT_FONT_SIZE = 72

BOOT_GFX_WIDTH = 36
BOOT_GFX_HEIGHT = 60
BOOT_GFX_FIRST = SPINNER_FIRST
BOOT_GFX_LAST = SPINNER_LAST

# ============================================================
# FONT FILES
# ============================================================

FONTS = {
    "Segoe UI.ttf": "SEGOEUI.FNT",
    "Segoe UI Bold.ttf": "SEGOEBD.FNT",
    "Segoe UI Italic.ttf": "SEGOEIT.FNT",
    "Segoe UI Bold Italic.ttf": "SEGOEBI.FNT",
}

BOOT_FONT = {
    "segoe_slboot.ttf": "BOOTSPIN.FNT",
}

# ============================================================
# NFNT HEADER
# ============================================================

def write_nfnt_header(out, first_char, glyph_count, width, height):
    out.write(b"NFNT")
    out.write(bytes([width, height]))
    out.write(first_char.to_bytes(2, "little"))
    out.write(glyph_count.to_bytes(2, "little"))

# ============================================================
# GROUNDED FONT RENDERING
# ============================================================

def render_normal_glyph(font, code):
    char = chr(code)
    image = Image.new("L", (WIDTH, HEIGHT), 0)

    if code == 32:
        return image

    bbox = font.getbbox(char)
    if bbox is None:
        return image

    left, top, right, bottom = bbox
    glyph_width = right - left
    glyph_height = bottom - top

    if glyph_width <= 0 or glyph_height <= 0:
        return image

    ascent, descent = font.getmetrics()

    temp = Image.new("L", (max(WIDTH, right + 10), ascent + descent + 10), 0)
    tdraw = ImageDraw.Draw(temp)
    tdraw.text((0, ascent), char, fill=255, font=font, anchor="ls")

    crop = temp.crop((left, 0, right, ascent + descent))

    # Keep all characters equal height and grounded on the exact same baseline!
    # If a character is wider than WIDTH (e.g. '@', 'M', 'W'), only scale width,
    # never scale height, so baseline and character size stay identical.
    if crop.width > WIDTH:
        crop = crop.resize((WIDTH, crop.height), Image.Resampling.LANCZOS)
        new_w = WIDTH
    else:
        new_w = crop.width

    paste_x = (WIDTH - new_w) // 2
    paste_y = BASELINE - ascent

    image.paste(crop, (paste_x, paste_y))
    return image

# ============================================================
# NORMAL FONT WRITER
# ============================================================

def write_normal_glyph(out, image):
    for y in range(HEIGHT):
        row = 0
        for x in range(WIDTH):
            if image.getpixel((x, y)) >= 90:
                row |= 1 << (15 - x)
        out.write(row.to_bytes(2, "little"))

# ============================================================
# BOOT SPINNER RENDERING
# ============================================================

def render_boot_glyph(font, code):
    char = chr(code)
    image = Image.new("L", (BOOT_WIDTH, BOOT_HEIGHT), 0)

    bbox = font.getbbox(char)
    if bbox is None:
        return image

    left, top, right, bottom = bbox
    if right <= left or bottom <= top:
        return image

    glyph_width = right - left
    glyph_height = bottom - top

    glyph = Image.new("L", (glyph_width, glyph_height), 0)
    draw = ImageDraw.Draw(glyph)
    draw.text((-left, -top), char, fill=255, font=font)

    scale = min(1.0, (BOOT_WIDTH - 2) / glyph.width, (BOOT_HEIGHT - 2) / glyph.height)
    if scale < 1.0:
        glyph = glyph.resize(
            (max(1, int(glyph.width * scale)), max(1, int(glyph.height * scale))),
            Image.Resampling.LANCZOS
        )

    x = (BOOT_WIDTH - glyph.width) // 2
    y = (BOOT_HEIGHT - glyph.height) // 2
    image.paste(glyph, (x, y))
    return image

# ============================================================
# BOOT SPINNER GRAPHICAL WRITER
# ============================================================

def write_boot_graphic_glyph(out, image):
    for y in range(BOOT_GFX_HEIGHT):
        for x in range(BOOT_GFX_WIDTH):
            value = image.getpixel((x, y))
            out.write(bytes([value]))

# ============================================================
# BOOT SPINNER WRITER
# ============================================================

def write_boot_glyph(out, image):
    ROW_BYTES = 5
    for y in range(BOOT_HEIGHT):
        for byte_index in range(ROW_BYTES):
            value = 0
            for bit in range(8):
                x = byte_index * 8 + bit
                if x >= BOOT_WIDTH:
                    break
                if image.getpixel((x, y)) >= 100:
                    value |= 1 << (7 - bit)
            out.write(bytes([value]))

# ============================================================
# CREATE NORMAL FONT
# ============================================================

def make_font(source_name, output_name):
    source = FONT_DIR / source_name
    output = FONT_DIR / output_name

    if not source.exists():
        raise FileNotFoundError(f"Missing font: {source}")

    font = ImageFont.truetype(str(source), FONT_SIZE)
    glyph_count = LAST_CHAR - FIRST_CHAR + 1

    with open(output, "wb") as out:
        write_nfnt_header(out, FIRST_CHAR, glyph_count, WIDTH, HEIGHT)
        for code in range(FIRST_CHAR, LAST_CHAR + 1):
            image = render_normal_glyph(font, code)
            write_normal_glyph(out, image)

    print(f"Created {output_name} ({WIDTH}x{HEIGHT})")

# ============================================================
# CREATE BOOT SPINNER
# ============================================================

def make_boot_spinner(source_name, output_name):
    source = FONT_DIR / source_name
    output = FONT_DIR / output_name

    if not source.exists():
        raise FileNotFoundError(f"Missing boot font: {source}")

    font = ImageFont.truetype(str(source), BOOT_FONT_SIZE)
    glyph_count = SPINNER_LAST - SPINNER_FIRST + 1

    with open(output, "wb") as out:
        write_nfnt_header(out, SPINNER_FIRST, glyph_count, BOOT_WIDTH, BOOT_HEIGHT)
        for code in range(SPINNER_FIRST, SPINNER_LAST + 1):
            image = render_boot_glyph(font, code)
            write_boot_glyph(out, image)

    print(f"Created {output_name} ({BOOT_WIDTH}x{BOOT_HEIGHT}, {glyph_count} frames)")

# ============================================================
# CREATE GRAPHICAL BOOT SPINNER
# ============================================================

def make_boot_graphic(source_name, output_name):
    source = FONT_DIR / source_name
    output = FONT_DIR / output_name

    if not source.exists():
        raise FileNotFoundError(f"Missing boot font: {source}")

    font = ImageFont.truetype(str(source), BOOT_FONT_SIZE)
    glyph_count = BOOT_GFX_LAST - BOOT_GFX_FIRST + 1

    with open(output, "wb") as out:
        write_nfnt_header(out, BOOT_GFX_FIRST, glyph_count, BOOT_GFX_WIDTH, BOOT_GFX_HEIGHT)
        for code in range(BOOT_GFX_FIRST, BOOT_GFX_LAST + 1):
            image = render_boot_glyph(font, code)
            write_boot_graphic_glyph(out, image)

    print(f"Created {output_name} ({BOOT_GFX_WIDTH}x{BOOT_GFX_HEIGHT}, {glyph_count} grayscale frames)")

# ============================================================
# BUILD NORMAL FONTS
# ============================================================

for source_name, output_name in FONTS.items():
    make_font(source_name, output_name)

# ============================================================
# BUILD BOOT SPINNER
# ============================================================

for source_name, output_name in BOOT_FONT.items():
    make_boot_spinner(source_name, output_name)

# ============================================================
# BUILD GRAPHICAL BOOT SPINNER
# ============================================================

for source_name, output_name in BOOT_FONT.items():
    make_boot_graphic(source_name, "BOOTSPIN.GFX")

print()
print("All NovaOS fonts created.")