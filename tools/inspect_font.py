from PIL import Image, ImageDraw, ImageFont

for sz in [14, 15, 16, 17, 18]:
    font = ImageFont.truetype("fonts/Segoe UI.ttf", sz)
    ascent, descent = font.getmetrics()
    print(f"sz={sz}: ascent={ascent}, descent={descent}, total={ascent+descent}")
    wide = []
    for c in range(33, 127):
        ch = chr(c)
        bb = font.getbbox(ch)
        w = bb[2] - bb[0]
        h = bb[3] - bb[1]
        if w > 12:
            wide.append((ch, w, h))
    print(f"  chars > 12px wide: {wide}")
