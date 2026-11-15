with open("kernel.asm", "rb") as f:
    data = f.read()

# 1. Shorten font setup strings
s1_old = b'font_setup_floppy   db "  Drive A: (Floppy .img) -> Scanned: found *.TTF glyphs ready",13,10,0'
s1_new = b'font_setup_floppy   db "  Drive A: Floppy (*.TTF ready)",13,10,0'

s2_old = b'font_setup_iso      db "  Drive D: (Optical .iso)-> Scanned: found *.TTF glyphs ready",13,10,0'
s2_new = b'font_setup_iso      db "  Drive D: Optical (*.TTF ready)",13,10,0'

s3_old = b'font_setup_novafs   db "  Drive C: (NovaFS HDD)  -> Active: Segoe UI Grounded (12x20)",13,10,0'
s3_new = b'font_setup_novafs   db "  Drive C: NovaFS (Segoe UI)",13,10,0'

s4_old = b'font_setup_prompt   db "Font engine active. Type \'font use bold/italic\' or \'savefont\' to persist to C:.",13,10,0'
s4_new = b'font_setup_prompt   db "Font engine ready.",13,10,0'

# 2. Shorten decorative borders in font setup & drive menu
b1_old = b'font_setup_banner   db "==================================================",13,10\r\n                    db "          NovaOS TrueType & Custom Font Setup     ",13,10\r\n                    db "==================================================",13,10,0'
b1_new = b'font_setup_banner   db "--- NovaOS Font Setup ---",13,10,0'

for old, new in [(s1_old, s1_new), (s2_old, s2_new), (s3_old, s3_new), (s4_old, s4_new)]:
    assert old in data, f"Not found: {old}"
    data = data.replace(old, new, 1)

if b1_old in data:
    data = data.replace(b1_old, b1_new, 1)
else:
    b1_old_lf = b1_old.replace(b"\r\n", b"\n")
    if b1_old_lf in data:
        data = data.replace(b1_old_lf, b1_new, 1)

with open("kernel.asm", "wb") as f:
    f.write(data)

print("Trimmed strings successfully!")
