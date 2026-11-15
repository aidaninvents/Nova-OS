with open("kernel.asm", "rb") as f:
    data = f.read()

idx_j = data.find(b'command_java:')
idx_h = data.find(b'command_html:')
idx_yt = data.find(b'command_youtube:')

compact_java = b'''command_java:
    cmp byte [app_installed_java], 1
    je .java_installed_ok
    mov rsi, str_app_not_installed
    call print
    jmp command_done

.java_installed_ok:
    mov byte [text_transparent_bg], 0
    mov dword [text_bg_color], 0x00000000
    mov dword [text_fg_color], 0x00F59E0B
    mov rsi, str_java_title
    call print
    mov al, 10
    call putchar
    mov dword [text_fg_color], 0x0010B981
    mov rsi, str_java_out_compiled
    call print
    mov al, 10
    call putchar
    jmp command_done

'''

compact_html = b'''command_html:
    cmp byte [app_installed_html], 1
    je .html_installed_ok
    mov rsi, str_app_not_installed
    call print
    jmp command_done

.html_installed_ok:
    mov byte [text_transparent_bg], 0
    mov dword [text_bg_color], 0x00000000
    mov dword [text_fg_color], 0x0006B6D4
    mov rsi, str_html_title
    call print
    mov al, 10
    call putchar
    mov dword [text_fg_color], 0x0038BDF8
    mov rsi, str_html_decoded_preview
    call print
    mov al, 10
    call putchar
    jmp command_done

'''

# Replace java and html
new_data = data[:idx_j] + compact_java + compact_html + data[idx_yt:]

# Re-enable the strict 64K assertion!
new_data = new_data.replace(b'%warning Over limit: %[$ - $$]', b'%if ($ - $$) > 65536\r\n    %error "NovaOS kernel is larger than 64 KiB"\r\n%endif')

with open("kernel.asm", "wb") as f:
    f.write(new_data)

print("Streamlined java and html! New size:", len(new_data))
