from PIL import Image, ImageDraw, ImageFont

font_path = "fonts/Segoe UI.ttf"
for size in [18, 20, 22, 24, 28, 30]:
    f = ImageFont.truetype(font_path, size)
    ascent, descent = f.getmetrics()
    print(f"Size {size}: ascent={ascent}, descent={descent}, total={ascent+descent}")
    for ch in ["A", "a", "g", "m", "M", "[", ".", "j", "T"]:
        bbox = f.getbbox(ch)
        print(f"  {ch}: bbox={bbox}, w={bbox[2]-bbox[0]}, h={bbox[3]-bbox[1]}")
