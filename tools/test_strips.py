from PIL import Image, ImageDraw, ImageFont

font_path = "fonts/Segoe UI.ttf"
test_text = "[ NovaOS ]  Files  Terminal  Settings"

for font_size, w, h, baseline in [
    (14, 12, 20, 15),
    (15, 12, 20, 15),
    (16, 12, 20, 15),
    (18, 12, 24, 18),
    (20, 12, 30, 22),
    (22, 12, 30, 23),
]:
    f = ImageFont.truetype(font_path, font_size)
    ascent, descent = f.getmetrics()
    
    # Strip of characters
    strip = Image.new("L", (w * len(test_text), h), 0)
    draw_strip = ImageDraw.Draw(strip)
    
    for i, ch in enumerate(test_text):
        if ch == ' ':
            continue
        # Render single character cell
        cell = Image.new("L", (w, h), 0)
        draw_cell = ImageDraw.Draw(cell)
        
        # Get glyph bbox
        bbox = f.getbbox(ch)
        if bbox:
            gw = bbox[2] - bbox[0]
            # Center horizontally within cell width w
            cx = (w - gw) // 2 - bbox[0]
            # Baseline alignment: draw so baseline falls exactly at `baseline`
            # In PIL, draw.text((x, y)) puts top of font box at y, or with anchor="ls":
            draw_cell.text((cx, baseline), ch, fill=255, font=f, anchor="ls")
        
        strip.paste(cell, (i * w, 0))
    
    strip.save(f"test_strip_{w}x{h}_sz{font_size}.png")
    print(f"Saved test_strip_{w}x{h}_sz{font_size}.png (ascent={ascent}, descent={descent})")
