with open("kernel.asm", "rb") as f:
    data = f.read()

import re

unref_labels = [
    b'str_java_out_ready',
    b'str_py_err_msg',
    b'str_java_interactive_btns',
    b'str_html_interactive_btns',
    b'gui_desktop_bar_text',
    b'str_py_sysver_out',
    b'str_ff_body',
    b'str_video_stream_footer',
    b'str_html_source_body',
    b'str_ff_url',
    b'str_py_zero_err',
    b'str_py_help_msg',
    b'str_chrome_results_hdr',
    b'str_java_code_body',
    b'str_ff_tab',
    b'str_chrome_search_text',
    b'str_ff_video_btn',
    b'str_bridge_inst_video',
    b'str_ns_link_wiki',
    b'str_chrome_default_q',
    b'gui_terminal_text',
    b'gui_settings_text',
    b'cmd_startup_nosp',
    b'cmd_browser_nosp',
    b'cmd_chrome_nosp',
    b'chr_saved_h',
    b'chr_saved_w',
    b'chr_saved_x',
    b'chr_saved_y',
]

removed_count = 0
for label in unref_labels:
    # Pattern to match label:\r?\n?\s*(db|dw|dd|dq)\s+[^\r\n]+(\r?\n\s*db\s+[^\r\n]+)*
    # Or simple label definition
    pattern = re.compile(rb'\b' + re.escape(label) + rb':(\r?\n)?(\s*(db|dw|dd|dq)\s+[^\r\n]+)+(\r?\n)?')
    m = pattern.search(data)
    if m:
        data = data[:m.start()] + data[m.end():]
        removed_count += 1
        print(f"Removed {label.decode()} ({m.end() - m.start()} bytes)")

# Strict check restoration
data = data.replace(b'%warning Over limit: %[$ - $$]', b'%if ($ - $$) > 65536\r\n    %error "NovaOS kernel is larger than 64 KiB"\r\n%endif')

with open("kernel.asm", "wb") as f:
    f.write(data)

print(f"Done! Removed {removed_count} unreferenced data blocks. New kernel.asm size: {len(data)}")
