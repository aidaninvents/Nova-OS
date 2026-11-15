with open("kernel.asm", "rb") as f:
    lines = f.readlines()

for i in range(8690, 8696):
    print(i+1, repr(lines[i]))

# Fix line 8692 and 8693
lines[8691] = b'    ; Send GET command to serial bridge\n'
lines[8692] = b'' # delete the stray quote line

with open("kernel.asm", "wb") as f:
    f.writelines(lines)

print("Applied exact line fix!")
