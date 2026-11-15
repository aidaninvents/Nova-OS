with open("kernel.asm", "rb") as f:
    data = f.read()

# Separate command_chrome and command_youtube
# In command_chrome (before command_youtube):
chrome_part, yt_part = data.split(b"command_youtube:")

# Replace in chrome_part: ensure .chrome_yt_v1, .chrome_yt_v2, .chrome_yt_v3
chrome_part = chrome_part.replace(b".yt_play_v1", b".chrome_yt_v1")
chrome_part = chrome_part.replace(b".yt_play_v2", b".chrome_yt_v2")
chrome_part = chrome_part.replace(b".yt_play_v3", b".chrome_yt_v3")

# Replace in yt_part: ensure .yt_play_v1, .yt_play_v2, .yt_play_v3
yt_part = yt_part.replace(b".chrome_yt_v1", b".yt_play_v1")
yt_part = yt_part.replace(b".chrome_yt_v2", b".yt_play_v2")
yt_part = yt_part.replace(b".chrome_yt_v3", b".yt_play_v3")

data = chrome_part + b"command_youtube:" + yt_part

with open("kernel.asm", "wb") as f:
    f.write(data)

print("Split replacement complete!")
