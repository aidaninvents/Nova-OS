import os
path = os.path.join(os.path.dirname(__file__), '..', 'build', 'stage2.bin')
b = open(path, 'rb').read()
used = len(b.rstrip(b'\x00'))
print(f"stage2.bin used: {used} / {len(b)} bytes (free: {len(b) - used} bytes)")
