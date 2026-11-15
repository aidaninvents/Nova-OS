with open("kernel.asm", "rb") as f:
    data = f.read()

import re

# Find all string definitions in the data section
matches = re.findall(rb'([a-zA-Z0-9_]+):\s+db\s+([^\r\n]+)', data)
print(f"Total db labels: {len(matches)}")

unref = []
for label, val in matches:
    # count occurrences outside the definition
    count = data.count(label)
    if count == 1:
        unref.append((label, len(val), val[:50]))

print(f"Unreferenced db strings: {len(unref)}")
total_bytes = sum(x[1] for x in unref)
print(f"Total unreferenced bytes in data section: {total_bytes}")
for label, l, val in sorted(unref, key=lambda x: x[1], reverse=True)[:25]:
    print(f"  {label.decode():30} ({l:3} bytes): {val}")
