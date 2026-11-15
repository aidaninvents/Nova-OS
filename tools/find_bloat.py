import re

with open("kernel.asm", "rb") as f:
    data = f.read()

# 1. Search for db tables / strings
matches = []
for m in re.finditer(rb'([a-zA-Z0-9_]+):\s*(db|dw|dd|dq)\s+([^\r\n]+)', data):
    label = m.group(1).decode('ascii', errors='ignore')
    op = m.group(2).decode('ascii', errors='ignore')
    val = m.group(3)
    matches.append((len(val), label, op, val[:60]))

matches.sort(key=lambda x: x[0], reverse=True)
print("Top 25 largest data declarations:")
for length, label, op, val in matches[:25]:
    print(f"{label:30} {op:4} {length:5} bytes: {val}")

# 2. Check unused or duplicate data
print("\nUnused python tables:")
for item in [b'str_py_help_msg', b'str_py_sysver_out', b'str_py_osname_out', b'str_py_mathpi_out', b'str_py_listcomp_out', b'str_py_def_out']:
    count = data.count(item)
    print(f"{item.decode()}: count = {count}")
