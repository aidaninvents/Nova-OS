#ifndef NOVAOS_BRIDGE_H
#define NOVAOS_BRIDGE_H

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/* NovaOS Framebuffer & Display Info */
typedef struct {
    uint64_t fb_address;
    uint32_t width;
    uint32_t height;
    uint32_t pitch;
    uint32_t bpp;
} novaos_display_t;

/* Exported Kernel Symbols from Assembly */
extern uint64_t framebuffer_address;
extern uint32_t framebuffer_pitch;
extern uint32_t screen_width;
extern uint32_t screen_height;
extern int32_t mouse_x;
extern int32_t mouse_y;
extern uint8_t mouse_buttons;

/* C Bridge Functions */
void novaos_bridge_init(void);
void novaos_fb_putpixel(int x, int y, uint32_t argb);
uint32_t novaos_fb_getpixel(int x, int y);
void novaos_fb_fillrect(int x, int y, int w, int h, uint32_t argb);
void novaos_fb_copyrect(int sx, int sy, int dx, int dy, int w, int h);
void novaos_fb_blit(const uint32_t *src, int dx, int dy, int w, int h, int stride);

/* Freestanding Heap Allocator */
void *novaos_malloc(size_t size);
void novaos_free(void *ptr);
void *novaos_calloc(size_t nmemb, size_t size);
void *novaos_realloc(void *ptr, size_t size);

/* Input & NetSurf Entry */
int novaos_get_key(void);
void novaos_get_mouse(int *x, int *y, int *buttons);
int novaos_netsurf_main(int argc, char **argv);

#ifdef __cplusplus
}
#endif

#endif /* NOVAOS_BRIDGE_H */
