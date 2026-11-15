from PIL import Image, ImageDraw, ImageFont

def render_grounded_glyph(font, code, width, height, baseline, max_scale_down=True):
    char = chr(code)
    cell = Image.new("L", (width, height), 0)
    
    if code == 32: # space
        return cell
        
    bbox = font.getbbox(char)
    if bbox is None:
        return cell
        
    left, top, right, bottom = bbox
    gw = right - left
    gh = bottom - top
    if gw <= 0 or gh <= 0:
        return cell

    # Horizontal scaling only if the character is wider than cell width
    # E.g. 'M', 'W', '@', 'm' might be 13-14px wide for a 12px cell
    scale = 1.0
    if gw > width and max_scale_down:
        scale = width / gw

    # Create temporary glyph image with full baseline context
    # Draw at an offset so nothing is clipped
    ascent, descent = font.getmetrics()
    temp_h = ascent + descent + 20
    temp_w = max(width, gw) + 20
    temp = Image.new("L", (temp_w, temp_h), 0)
    draw_temp = ImageDraw.Draw(temp)
    
    # Draw at fixed baseline inside temp
    temp_baseline = ascent + 5
    draw_temp.text((5, temp_baseline), char, fill=255, font=font, anchor="ls")
    
    # Crop precisely around the character horizontally, but keep vertical baseline reference!
    char_left = 5 + left
    char_right = 5 + right
    char_w = char_right - char_left
    
    glyph_crop = temp.crop((char_left, 5, char_right, 5 + ascent + descent))
    
    if scale < 1.0:
        new_w = max(1, int(char_w * scale))
        new_h = max(1, int((ascent + descent) * scale))
        glyph_crop = glyph_crop.resize((new_w, new_h), Image.Resampling.LANCZOS)
        # Scale baseline accordingly
        scaled_ascent = int(ascent * scale)
    else:
        new_w = char_w
        scaled_ascent = ascent

    # Position in final cell:
    # Horizontally centered:
    x = (width - new_w) // 2
    # Vertically: place so its baseline aligns with the target `baseline`
    y = baseline - scaled_ascent
    
    cell.paste(glyph_crop, (x, y))
    return cell

# Test on 12x20 and 12x30
for w, h, sz, bl in [(12, 20, 15, 15), (12, 30, 22, 23)]:
    font = ImageFont.truetype("fonts/Segoe UI.ttf", sz)
    cols = 16
    rows = (95 + cols - 1) // cols
    sheet = Image.new("L", (cols * w, rows * h), 0)
    for idx, code in enumerate(range(32, 127)):
        g = render_grounded_glyph(font, code, w, h, bl)
        cx = (idx % cols) * w
        cy = (idx // cols) * h
        sheet.paste(g, (cx, cy))
    sheet.save(f"charsheet_{w}x{h}.png")
    print(f"Generated charsheet_{w}x{h}.png")
