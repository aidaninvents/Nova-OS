import re

with open("kernel.asm", "rb") as f:
    d = f.read()

print("kernel.asm total text size:", len(d))

# Look at Python REPL strings in kernel.asm
py_strings = [
    m.group(0) for m in re.finditer(rb'str_py_[a-zA-Z0-9_]+\s+db\s+[^\r\n]+', d)
]
print("Python REPL string definitions:", len(py_strings))
for s in py_strings:
    print("  ", s[:80])

# Look at shop strings
shop_strings = [
    m.group(0) for m in re.finditer(rb'str_shop_[a-zA-Z0-9_]+\s+db\s+[^\r\n]+', d)
]
print("Shop string definitions:", len(shop_strings))
