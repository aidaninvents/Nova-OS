with open("kernel.asm", "rb") as f:
    data = f.read()

bad = b'; Send "GET " + ns_current_url + "\\n\n"\n'
good = b'; Send GET command to serial bridge\n'

if bad not in data:
    bad = b'; Send "GET " + ns_current_url + "\\n\r\n"\r\n'
    good = b'; Send GET command to serial bridge\r\n'

print("bad found:", bad in data)
data = data.replace(bad, good)

with open("kernel.asm", "wb") as f:
    f.write(data)

print("Fixed comment line in kernel.asm!")
