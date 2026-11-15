from PIL import Image, ImageDraw, ImageFont

# Test rendering sample text with baseline grounding vs original
font_path = "fonts/Segoe UI.ttf"

def render_sample(font_size, baseline_y, name):
    font = ImageFont.truetype(font_path, font_size)
    ascent, descent = font.getmetrics()
    
    # We want a 12x20 cell for each character
    w = 12
    h = 20
    
    chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 .,:;!?@#$%^&*()_+-=[]{}|\\/"
    
    # Create image for all characters side-by-side
    img = Image.new("L", (len(chars) * w, h), 0)
    
    for i, ch in enumerate(chars):
        cell = Image.new("L", (w, h), 0)
        
        # Get bounding box
        bbox = font.getbbox(ch)
        if bbox is not None and ch != " ":
            left, top, right, bottom = bbox
            gw = right - left
            gh = bottom - top
            
            # Temporary image with enough room
            temp = Image.new("L", (max(w, right + 10), ascent + descent + 10), 0)
            tdraw = ImageDraw.Draw(temp)
            # Draw with baseline at ascent
            tdraw.text((0, ascent), ch, fill=255, font=font, anchor="ls")
            
            # Crop exactly the character from x=left to right
            # But keep the vertical span from top to bottom
            crop = temp.crop((left, 0, right, ascent + descent))
            
            # If gw > w (e.g. 'M', 'W', '@'), only scale horizontally to fit w!
            # Do NOT scale vertically, so height and baseline remain identical!
            if gw > w:
                crop = crop.resize((w, crop.height), Image.Resampling.LANCZOS)
                new_w = w
            else:
                new_w = gw
                
            paste_x = (w - new_w) // 2
            # The baseline in crop is at y = ascent.
            # We want baseline in cell to be at baseline_y.
            # So paste_y = baseline_y - ascent
            paste_y = baseline_y - ascent
            
            cell.paste(crop, (paste_x, paste_y))
            
        img.paste(cell, (i * w, 0))
        
    img.save(name)
    print(f"Saved {name}")

for sz in [14, 15, 16]:
    font = ImageFont.truetype(font_path, sz)
    asc, desc = font.getmetrics()
    # Baseline at row 15 (giving 4 rows for descenders like g, j, p, q, y)
    render_sample(sz, 15, f"sample_sz{sz}.png")
