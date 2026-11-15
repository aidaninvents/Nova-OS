#ifndef NOVA_BROWSER_BRIDGE_H
#define NOVA_BROWSER_BRIDGE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* =========================================================================
 * Nova OS Assembly Hooks (provided by Nova OS kernel / chrome.nosp stub)
 * System V AMD64 ABI: RDI, RSI, RDX, RCX, R8, R9
 * ========================================================================= */
extern void* malloc(size_t size);
extern void  free(void* ptr);
extern void* realloc(void* ptr, size_t new_size);

/* Fetches URL over Nova OS TLS 1.3 stack; returns heap-allocated NUL-terminated buffer
 * (or NULL on failure) and optionally writes byte length to *out_len. */
extern char* https_fetch(const char* url, size_t* out_len);

/* Framebuffer & UI drawing hooks (color is 0xAARRGGBB) */
extern void draw_rect(int32_t x, int32_t y, int32_t w, int32_t h, uint32_t argb);
extern void draw_text(int32_t x, int32_t y, const char* text, uint32_t argb, uint32_t font_size_px);
extern void draw_image(int32_t x, int32_t y, int32_t w, int32_t h, const uint32_t* bgra_pixels);
extern void set_clip_rect(int32_t x, int32_t y, int32_t w, int32_t h);

/* Input globals exported by Nova OS assembly */
extern volatile int32_t mouse_x;
extern volatile int32_t mouse_y;
extern volatile uint8_t mouse_clicked;

/* =========================================================================
 * C++ LiteHTML -> x86_64 Assembly Bridge API (System V AMD64 ABI)
 * ========================================================================= */

/* RDI = viewport_w, RSI = viewport_h -> returns 0 on success, <0 on error */
int browser_init(uint32_t viewport_w, uint32_t viewport_h);

/* RDI = html (NUL-terminated), RSI = base_url (NUL-terminated or NULL) -> returns 0 on success */
int browser_load_html(const char* html, const char* base_url);

/* RDI = scroll_x, RSI = scroll_y */
void browser_render(int32_t scroll_x, int32_t scroll_y);

/* RDI = mouse_x, RSI = mouse_y -> returns 1 if anchor clicked / redraw needed, 0 otherwise */
int browser_on_click(int32_t x, int32_t y);

/* RDI = delta_y -> clamps scroll offset and returns updated scroll_y */
int32_t browser_scroll(int32_t delta_y);

/* Returns last clicked anchor URL (or NULL if none), and clears it */
const char* browser_get_pending_url(void);
void browser_clear_pending_url(void);

/* RDI = client_id, RSI = redirect_uri -> loads Google OAuth 2.0 consent page into LiteHTML */
int browser_start_oauth(const char* client_id, const char* redirect_uri);

#ifdef __cplusplus
}
#endif

#endif /* NOVA_BROWSER_BRIDGE_H */
