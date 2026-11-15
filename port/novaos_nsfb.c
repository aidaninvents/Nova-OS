/*
 * port/novaos_nsfb.c
 * Direct NovaOS Framebuffer Driver for NetSurf libnsfb
 * Bypasses SDL/X11 and plots raw 32-bit ARGB pixels directly to video memory.
 */

#include "novaos_bridge.h"

typedef struct {
    uint8_t r, g, b, a;
} nsfb_colour_t;

typedef struct {
    int x0, y0, x1, y1;
} nsfb_bbox_t;

/* Direct Framebuffer Surface State */
typedef struct {
    uint8_t *ptr;
    int width;
    int height;
    int pitch;
    int bpp;
    nsfb_bbox_t clip;
} novaos_nsfb_surface_t;

static novaos_nsfb_surface_t g_surface;

/* Initialize Direct NovaOS Surface */
bool novaos_nsfb_init(int width, int height) {
    g_surface.ptr = (uint8_t *)framebuffer_address;
    if (!g_surface.ptr) {
        g_surface.ptr = (uint8_t *)(*(volatile uint64_t *)0x9000);
    }
    g_surface.pitch = framebuffer_pitch ? framebuffer_pitch : *(volatile uint32_t *)0x9004;
    g_surface.width = width > 0 ? width : (int)(screen_width ? screen_width : 1024);
    g_surface.height = height > 0 ? height : (int)(screen_height ? screen_height : 768);
    g_surface.bpp = 32;

    g_surface.clip.x0 = 0;
    g_surface.clip.y0 = 0;
    g_surface.clip.x1 = g_surface.width;
    g_surface.clip.y1 = g_surface.height;

    return (g_surface.ptr != NULL);
}

/* Set Clipping Rectangle */
bool novaos_nsfb_set_clip(const nsfb_bbox_t *clip) {
    if (!clip) return false;
    g_surface.clip = *clip;
    if (g_surface.clip.x0 < 0) g_surface.clip.x0 = 0;
    if (g_surface.clip.y0 < 0) g_surface.clip.y0 = 0;
    if (g_surface.clip.x1 > g_surface.width) g_surface.clip.x1 = g_surface.width;
    if (g_surface.clip.y1 > g_surface.height) g_surface.clip.y1 = g_surface.height;
    return true;
}

/* Direct Pixel Plotter (32-bit ARGB) */
bool novaos_nsfb_plot_point(int x, int y, uint32_t colour) {
    if (x < g_surface.clip.x0 || x >= g_surface.clip.x1 ||
        y < g_surface.clip.y0 || y >= g_surface.clip.y1) {
        return true;
    }
    novaos_fb_putpixel(x, y, colour);
    return true;
}

/* Direct Horizontal / Vertical Lines */
bool novaos_nsfb_plot_line(int x0, int y0, int x1, int y1, uint32_t colour) {
    if (y0 == y1) {
        int start_x = x0 < x1 ? x0 : x1;
        int end_x = x0 < x1 ? x1 : x0;
        for (int x = start_x; x <= end_x; x++) {
            novaos_nsfb_plot_point(x, y0, colour);
        }
        return true;
    }
    /* Bresenham's line algorithm for arbitrary lines */
    int dx = x1 > x0 ? (x1 - x0) : (x0 - x1);
    int dy = y1 > y0 ? (y1 - y0) : (y0 - y1);
    int sx = x0 < x1 ? 1 : -1;
    int sy = y0 < y1 ? 1 : -1;
    int err = (dx > dy ? dx : -dy) / 2;

    while (1) {
        novaos_nsfb_plot_point(x0, y0, colour);
        if (x0 == x1 && y0 == y1) break;
        int e2 = err;
        if (e2 > -dx) { err -= dy; x0 += sx; }
        if (e2 < dy) { err += dx; y0 += sy; }
    }
    return true;
}

/* Direct Rectangle Fill */
bool novaos_nsfb_plot_fill(int x0, int y0, int x1, int y1, uint32_t colour) {
    int rx = x0 < x1 ? x0 : x1;
    int ry = y0 < y1 ? y0 : y1;
    int rw = (x0 < x1 ? (x1 - x0) : (x0 - x1)) + 1;
    int rh = (y0 < y1 ? (y1 - y0) : (y0 - y1)) + 1;

    /* Clip to active bounding box */
    if (rx < g_surface.clip.x0) { rw -= (g_surface.clip.x0 - rx); rx = g_surface.clip.x0; }
    if (ry < g_surface.clip.y0) { rh -= (g_surface.clip.y0 - ry); ry = g_surface.clip.y0; }
    if (rx + rw > g_surface.clip.x1) rw = g_surface.clip.x1 - rx;
    if (ry + rh > g_surface.clip.y1) rh = g_surface.clip.y1 - ry;

    if (rw <= 0 || rh <= 0) return true;
    novaos_fb_fillrect(rx, ry, rw, rh, colour);
    return true;
}

/* Direct Bitmap Blit */
bool novaos_nsfb_plot_bitmap(const uint32_t *bitmap, int x, int y, int width, int height) {
    if (!bitmap) return false;
    novaos_fb_blit(bitmap, x, y, width, height, width);
    return true;
}
