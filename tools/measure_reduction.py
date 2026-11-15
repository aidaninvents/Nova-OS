with open("kernel.asm", "rb") as f:
    data = f.read()

import re

# Check for unused labels in data section
labels = re.findall(rb'([a-zA-Z0-9_]+):', data)
print(f"Total labels found: {len(labels)}")

# Check references
unused = []
for label in set(labels):
    if label.startswith(b'.'):
        continue
    # Count occurrences
    count = data.count(label)
    if count == 1: # only defined, never used
        unused.append(label)

print(f"Unused labels ({len(unused)}):")
for u in sorted(unused)[:30]:
    print(" ", u.decode(errors='ignore'))
