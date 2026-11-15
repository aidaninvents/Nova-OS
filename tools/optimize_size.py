with open("kernel.asm", "rb") as f:
    data = f.read()

print("Original data size:", len(data))

# 1. Alias command_firefox to command_netsurf
idx_ff = data.find(b'command_firefox:\r\n')
idx_ns = data.find(b'; NETSURF WEB BROWSER')
if idx_ff != -1 and idx_ns != -1:
    ff_stub = b'''command_firefox:\r
    jmp command_netsurf\r
\r
'''
    data = data[:idx_ff] + ff_stub + data[idx_ns:]
    print("Replaced command_firefox with alias to command_netsurf")

# 2. Remove unused Firefox and old Python strings
# Find str_py_help_msg to str_ff_body
idx_py_help = data.find(b'str_py_help_msg:\r\n')
idx_live_web = data.find(b'str_live_web_banner:\r\n')
if idx_py_help != -1 and idx_live_web != -1 and idx_py_help < idx_live_web:
    print(f"Removing old mock strings block: {idx_live_web - idx_py_help} bytes")
    data = data[:idx_py_help] + data[idx_live_web:]

# 3. Restore the 64k limit check
data = data.replace(b'%warning Kernel size is over 64k: %[$ - $$]', b'%if ($ - $$) > 65536\r\n    %error "NovaOS kernel is larger than 64 KiB"\r\n%endif')

with open("kernel.asm", "wb") as f:
    f.write(data)

print("Optimized kernel.asm size:", len(data))
