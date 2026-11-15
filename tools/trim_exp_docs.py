import re
with open("kernel.asm", "rb") as f:
    data = f.read()

# Strip trailing spaces right before ",13,10 or ",0 in str_exp_modal_*
before = len(data)
# Only inside str_exp_modal section
start = data.find(b"str_exp_modal_docs:")
end = data.find(b"str_yt_v1_title:")
assert start != -1 and end != -1 and start < end
seg = data[start:end]
seg_clean = re.sub(rb' {2,}",', rb'",', seg)
data = data[:start] + seg_clean + data[end:]

with open("kernel.asm", "wb") as f:
    f.write(data)
print(f"Stripped {len(seg) - len(seg_clean)} trailing space bytes from Explorer modal strings.")
