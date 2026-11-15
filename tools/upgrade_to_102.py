import re

with open("kernel.asm", "rb") as f:
    d = f.read()

print("Original kernel.asm size:", len(d))

# Check command_python block
idx_py = d.find(b"command_python:")
idx_py_end = d.find(b"; ============================================================\r\n; BROWSER", idx_py)
if idx_py_end == -1:
    idx_py_end = d.find(b"; BROWSER", idx_py)
print(f"command_python length: {idx_py_end - idx_py} bytes")
print("Snippet:", repr(d[idx_py:idx_py+200]))
