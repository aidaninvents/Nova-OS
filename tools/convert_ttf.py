#!/usr/bin/env python3
"""
NovaOS TrueType to NFNT Bitmap Font Converter
Converts any TTF/OTF font into a 12x20 baseline-grounded NovaOS bitmap font (.FNT).
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

WIDTH = 12
HEIGHT = 20
FONT_SIZE = 15
BASELINE = 15
FIRST_CHAR = 32
LAST_CHAR = 126

def write_nfnt_header(out, first_char, glyph_count, width, height):
    out.write(b"NFNT")
    out.write(bytes([width, height]))
    out.write(first_char.to_bytes(2, "little"))
    out.write(glyph_count.to_bytes(2, "little"))

def render_grounded_glyph(font, code):
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
    if crop.width > WIDTH:
        crop = crop.resize((WIDTH, crop.height), Image.Resampling.LANCZOS)
        new_w = WIDTH
    else:
        new_w = crop.width

    paste_x = (WIDTH - new_w) // 2
    paste_y = BASELINE - ascent

    image.paste(crop, (paste_x, paste_y))
    return image

def write_glyph_bitmap(out, image):
    for y in range(HEIGHT):
        row = 0
        for x in range(WIDTH):
            if image.getpixel((x, y)) >= 90:
                row |= (1 << (15 - x))
        out.write(row.to_bytes(2, "little"))

def convert_ttf_to_nfnt(ttf_path, output_fnt_path):
    font = ImageFont.truetype(str(ttf_path), FONT_SIZE)
    glyph_count = LAST_CHAR - FIRST_CHAR + 1

    with open(output_fnt_path, "wb") as out:
        write_nfnt_header(out, FIRST_CHAR, glyph_count, WIDTH, HEIGHT)
        for code in range(FIRST_CHAR, LAST_CHAR + 1):
            glyph_img = render_grounded_glyph(font, code)
            write_glyph_bitmap(out, glyph_img)

    print(f"Successfully converted '{ttf_path}' -> '{output_fnt_path}' ({WIDTH}x{HEIGHT}, {glyph_count} glyphs)")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: convert_ttf.py <input.ttf> <output.fnt>")
        sys.exit(1)
    convert_ttf_to_nfnt(sys.argv[1], sys.argv[2])
