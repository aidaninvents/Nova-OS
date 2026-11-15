from PIL import Image, ImageDraw, ImageFont

font = ImageFont.truetype("fonts/Segoe UI.ttf", 15)
ascent, descent = font.getmetrics()

w, h = 12, 20
baseline_y = 15

glyphs = {}
for code in range(32, 127):
    ch = chr(code)
    cell = Image.new("L", (w, h), 0)
    if ch != " ":
        bbox = font.getbbox(ch)
        if bbox is not None:
            left, top, right, bottom = bbox
            gw = right - left
            gh = bottom - top
            if gw > 0 and gh > 0:
                temp = Image.new("L", (max(w, right + 10), ascent + descent + 10), 0)
                tdraw = ImageDraw.Draw(temp)
                tdraw.text((0, ascent), ch, fill=255, font=font, anchor="ls")
                crop = temp.crop((left, 0, right, ascent + descent))
                if gw > w:
                    crop = crop.resize((w, crop.height), Image.Resampling.LANCZOS)
                    new_w = w
                else:
                    new_w = gw
                paste_x = (w - new_w) // 2
                paste_y = baseline_y - ascent
                cell.paste(crop, (paste_x, paste_y))
    # Threshold to 1-bit bitmap
    bitmap = []
    for y in range(h):
        row = 0
        for x in range(w):
            if cell.getpixel((x, y)) >= 90:
                row |= (1 << (15 - x))
        bitmap.append(row)
    glyphs[code] = bitmap

# Render sample NovaOS desktop text
lines = [
    "NovaOS Version 1.0 (64-bit Kernel)",
    "CPU: Intel Core i7 / AMD Ryzen",
    "Memory: 512 MB RAM detected",
    "Floppy Drive: 1.44MB A: [Ready]",
    "Hard Disk: ATA 2048 MB C: [Mounted]",
    "Custom Font: SEGOEUI.FNT loaded",
    "The quick brown fox jumps over the lazy dog.",
    "0123456789 !@#$%^&*()_+-=[]{}|;':\",./<>?"
]

preview = Image.new("RGB", (800, len(lines) * h + 20), (18, 24, 32))
pdraw = ImageDraw.Draw(preview)

for row_idx, line in enumerate(lines):
    for col_idx, ch in enumerate(line):
        code = ord(ch) if 32 <= ord(ch) <= 126 else 32
        bmp = glyphs[code]
        for y in range(h):
            row_val = bmp[y]
            for x in range(w):
                if row_val & (1 << (15 - x)):
                    preview.putpixel((10 + col_idx * w + x, 10 + row_idx * h + y), (255, 255, 255))

preview.save("font_desktop_preview.png")
print("Saved font_desktop_preview.png")
