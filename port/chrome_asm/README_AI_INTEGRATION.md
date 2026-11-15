# `chrome.nosp` — The First Portable x86_64 Assembly Web Browser

`chrome.nosp` is a standalone, position-independent, zero-dependency 64-bit x86_64 NASM browser binary (`port/chrome_asm/chrome.asm`) designed so **any AI agent, VM runtime, or custom OS** can drop it into memory and run a real box-and-link web browser.

## Binary Header & Export Table (`ORG 0`)
| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| `0x00` | 4B | `"NOSP"` | NovaOS Portable Executable Magic |
| `0x04` | 4B | `1` | Format version |
| `0x08` | 8B | `"ASMBROWS"` | Portable ASM Browser Signature |
| `0x10` | 4B | `0x00010000` | ABI v1.0 |
| `0x14` | 4B | `64` | `NVBX` Box Record size in bytes |
| `0x18` | 8B | `chrome_asm_init` | `RDI = host_api_table*` |
| `0x20` | 8B | `chrome_asm_parse_html` | `RDI=html, RSI=len, RDX=out_boxes, RCX=max -> RAX=count` |
| `0x28` | 8B | `chrome_asm_render` | `RDI=boxes, RSI=count` |
| `0x30` | 8B | `chrome_asm_on_click` | `RDI=boxes, RSI=count, RDX=mx, RCX=my -> RAX=link_id` |
| `0x38` | 8B | `chrome_asm_navigate` | `RDI=url, RSI=html_buf, RDX=boxes, RCX=max -> RAX=count` |

All entry offsets in `0x18..0x38` are relative to the load base of `chrome.nosp` (`base + offset`).

## Host API Callback Table (4 QWORDs)
Pass a pointer to 4 System V AMD64 function pointers in `RDI` to `chrome_asm_init`:
1. `+0x00`: `void draw_rect(uint32_t x, uint32_t y, uint32_t w, uint32_t h, uint32_t rgb)`
2. `+0x08`: `void draw_text(uint32_t x, uint32_t y, const char* text, uint32_t rgb)`
3. `+0x10`: `int64_t net_fetch(const char* url, char* out_buf, uint32_t max_len)`
4. `+0x18`: `void log_msg(const char* text)`

## `NVBX` Box Record Layout (64 bytes)
| Offset | Type | Field |
|--------|------|-------|
| `0x00` | `uint16_t` | `x` |
| `0x02` | `uint16_t` | `y` |
| `0x04` | `uint16_t` | `w` |
| `0x06` | `uint16_t` | `h` |
| `0x08` | `uint32_t` | `bg_color` (`0x00RRGGBB`) |
| `0x0C` | `uint32_t` | `fg_color` (`0x00RRGGBB`) |
| `0x10` | `uint8_t` | `link_id` (`0` = static box/card/input, `1..N` = clickable link) |
| `0x11` | `uint8_t` | `flags` (bit 0 = draw border, bit 1 = underline) |
| `0x12` | `char[46]` | Null-terminated ASCII text |

## Build
```bash
nasm -f bin port/chrome_asm/chrome.asm -o build/chrome.nosp
```
