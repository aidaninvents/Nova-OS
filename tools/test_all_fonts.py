from PIL import Image, ImageDraw, ImageFont

fonts = [
    "fonts/Segoe UI.ttf",
    "fonts/Segoe UI Bold.ttf",
    "fonts/Segoe UI Italic.ttf",
    "fonts/Segoe UI Bold Italic.ttf"
]

w = 12
h = 20
font_size = 15
baseline_y = 15

chars = [chr(c) for c in range(32, 127)]

for fp in fonts:
    font = ImageFont.truetype(fp, font_size)
    ascent, descent = font.getmetrics()
    print(f"Font: {fp}, ascent: {ascent}, descent: {descent}")
    
    img = Image.new("L", (len(chars) * w, h), 0)
    
    for i, ch in enumerate(chars):
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
        img.paste(cell, (i * w, 0))
    
    out_name = fp.replace("fonts/", "sample_").replace(".ttf", ".png").replace(" ", "_")
    img.save(out_name)
    print(f"Saved {out_name}")
