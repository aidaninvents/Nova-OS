from PIL import Image, ImageDraw, ImageFont

font_path = "fonts/Segoe UI.ttf"
for sz in [13, 14, 15, 16, 17, 18, 19, 20]:
    f = ImageFont.truetype(font_path, sz)
    max_w = 0
    widest_char = ''
    for code in range(32, 127):
        ch = chr(code)
        bbox = f.getbbox(ch)
        if bbox:
            w = bbox[2] - bbox[0]
            if w > max_w:
                max_w = w
                widest_char = ch
    print(f"Font size {sz}: max_w={max_w} ('{widest_char}'), 'M'={f.getbbox('M')[2]-f.getbbox('M')[0]}, 'm'={f.getbbox('m')[2]-f.getbbox('m')[0]}, 'W'={f.getbbox('W')[2]-f.getbbox('W')[0]}")
