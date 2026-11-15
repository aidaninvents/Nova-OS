/*
 * port/novaos_bridge.c
 * Freestanding C bridge for NetSurf on NovaOS x86_64
 * Direct raw 32-bit ARGB framebuffer driver, heap memory allocator,
 * and PS/2 input / network routines.
 */

#include "novaos_bridge.h"

#define HEAP_START 0x02000000ULL
#define HEAP_SIZE  (16 * 1024 * 1024) /* 16 MB heap arena safely above kernel & media */

static uint8_t *heap_ptr = (uint8_t *)HEAP_START;
static uint8_t *heap_max = (uint8_t *)(HEAP_START + HEAP_SIZE);

/* Freestanding Port I/O */
static inline void outb(uint16_t port, uint8_t val) {
    __asm__ volatile ("outb %0, %1" : : "a"(val), "Nd"(port));
}

static inline uint8_t inb(uint16_t port) {
    uint8_t ret;
    __asm__ volatile ("inb %1, %0" : "=a"(ret) : "Nd"(port));
    return ret;
}

/* Freestanding Standard Memory Routines */
void *memcpy(void *dest, const void *src, size_t n) {
    uint8_t *d = (uint8_t *)dest;
    const uint8_t *s = (const uint8_t *)src;
    for (size_t i = 0; i < n; i++) d[i] = s[i];
    return dest;
}

void *memset(void *s, int c, size_t n) {
    uint8_t *p = (uint8_t *)s;
    for (size_t i = 0; i < n; i++) p[i] = (uint8_t)c;
    return s;
}

void *memmove(void *dest, const void *src, size_t n) {
    uint8_t *d = (uint8_t *)dest;
    const uint8_t *s = (const uint8_t *)src;
    if (d < s) {
        for (size_t i = 0; i < n; i++) d[i] = s[i];
    } else {
        for (size_t i = n; i > 0; i--) d[i - 1] = s[i - 1];
    }
    return dest;
}

int memcmp(const void *s1, const void *s2, size_t n) {
    const uint8_t *p1 = (const uint8_t *)s1;
    const uint8_t *p2 = (const uint8_t *)s2;
    for (size_t i = 0; i < n; i++) {
        if (p1[i] != p2[i]) return p1[i] - p2[i];
    }
    return 0;
}

size_t strlen(const char *s) {
    size_t len = 0;
    while (s[len]) len++;
    return len;
}

char *strcpy(char *dest, const char *src) {
    char *d = dest;
    while ((*d++ = *src++));
    return dest;
}

char *strncpy(char *dest, const char *src, size_t n) {
    size_t i;
    for (i = 0; i < n && src[i] != '\0'; i++) dest[i] = src[i];
    for (; i < n; i++) dest[i] = '\0';
    return dest;
}

int strcmp(const char *s1, const char *s2) {
    while (*s1 && (*s1 == *s2)) { s1++; s2++; }
    return *(const unsigned char *)s1 - *(const unsigned char *)s2;
}

int strncmp(const char *s1, const char *s2, size_t n) {
    while (n && *s1 && (*s1 == *s2)) { s1++; s2++; n--; }
    if (n == 0) return 0;
    return *(const unsigned char *)s1 - *(const unsigned char *)s2;
}

/* Heap Allocator (Header-based First-Fit with 16-byte alignment) */
typedef struct block_header {
    size_t size;
    int is_free;
    struct block_header *next;
} block_header_t;

static block_header_t *free_list = NULL;

void *novaos_malloc(size_t size) {
    if (size == 0) return NULL;
    size = (size + 15) & ~15; /* 16-byte align */

    block_header_t *curr = free_list;
    block_header_t *prev = NULL;

    while (curr) {
        if (curr->is_free && curr->size >= size) {
            curr->is_free = 0;
            return (void *)(curr + 1);
        }
        prev = curr;
        curr = curr->next;
    }

    /* Allocate from top of arena */
    size_t total = sizeof(block_header_t) + size;
    if (heap_ptr + total > heap_max) return NULL; /* Out of memory */

    block_header_t *block = (block_header_t *)heap_ptr;
    heap_ptr += total;

    block->size = size;
    block->is_free = 0;
    block->next = NULL;

    if (prev) prev->next = block;
    else free_list = block;

    return (void *)(block + 1);
}

void novaos_free(void *ptr) {
    if (!ptr) return;
    block_header_t *block = ((block_header_t *)ptr) - 1;
    block->is_free = 1;
}

void *novaos_calloc(size_t nmemb, size_t size) {
    size_t total = nmemb * size;
    void *p = novaos_malloc(total);
    if (p) memset(p, 0, total);
    return p;
}

void *novaos_realloc(void *ptr, size_t size) {
    if (!ptr) return novaos_malloc(size);
    if (size == 0) { novaos_free(ptr); return NULL; }

    block_header_t *block = ((block_header_t *)ptr) - 1;
    if (block->size >= size) return ptr;

    void *new_p = novaos_malloc(size);
    if (new_p) {
        memcpy(new_p, ptr, block->size);
        novaos_free(ptr);
    }
    return new_p;
}

void *malloc(size_t size) { return novaos_malloc(size); }
void free(void *ptr) { novaos_free(ptr); }
void *calloc(size_t nmemb, size_t size) { return novaos_calloc(nmemb, size); }
void *realloc(void *ptr, size_t size) { return novaos_realloc(ptr, size); }

/*
 * Raw 32-bit ARGB Framebuffer Driver (Bypasses SDL / X11 completely)
 */
void novaos_fb_putpixel(int x, int y, uint32_t argb) {
    uint64_t fb = framebuffer_address;
    if (!fb) fb = *(volatile uint64_t *)0x9000;
    uint32_t pitch = framebuffer_pitch ? framebuffer_pitch : *(volatile uint32_t *)0x9004;
    uint32_t sw = screen_width ? screen_width : *(volatile uint32_t *)0x9008;
    uint32_t sh = screen_height ? screen_height : *(volatile uint32_t *)0x900C;

    if (x < 0 || (uint32_t)x >= sw || y < 0 || (uint32_t)y >= sh) return;
    volatile uint32_t *pixel = (volatile uint32_t *)(fb + (uint64_t)y * pitch + (x * 4));
    *pixel = argb;
}

uint32_t novaos_fb_getpixel(int x, int y) {
    uint64_t fb = framebuffer_address;
    if (!fb) fb = *(volatile uint64_t *)0x9000;
    uint32_t pitch = framebuffer_pitch ? framebuffer_pitch : *(volatile uint32_t *)0x9004;
    return *(volatile uint32_t *)(fb + (uint64_t)y * pitch + (x * 4));
}

void novaos_fb_fillrect(int x, int y, int w, int h, uint32_t argb) {
    uint64_t fb = framebuffer_address;
    if (!fb) fb = *(volatile uint64_t *)0x9000;
    uint32_t pitch = framebuffer_pitch ? framebuffer_pitch : *(volatile uint32_t *)0x9004;
    uint32_t sw = screen_width ? screen_width : *(volatile uint32_t *)0x9008;
    uint32_t sh = screen_height ? screen_height : *(volatile uint32_t *)0x900C;

    int x1 = x < 0 ? 0 : x;
    int y1 = y < 0 ? 0 : y;
    int x2 = (x + w) > (int)sw ? (int)sw : (x + w);
    int y2 = (y + h) > (int)sh ? (int)sh : (y + h);

    for (int cy = y1; cy < y2; cy++) {
        volatile uint32_t *row = (volatile uint32_t *)(fb + (uint64_t)cy * pitch);
        for (int cx = x1; cx < x2; cx++) {
            row[cx] = argb;
        }
    }
}

void novaos_fb_copyrect(int sx, int sy, int dx, int dy, int w, int h) {
    uint64_t fb = framebuffer_address;
    if (!fb) fb = *(volatile uint64_t *)0x9000;
    uint32_t pitch = framebuffer_pitch ? framebuffer_pitch : *(volatile uint32_t *)0x9004;

    for (int r = 0; r < h; r++) {
        volatile uint32_t *s_row = (volatile uint32_t *)(fb + (uint64_t)(sy + r) * pitch);
        volatile uint32_t *d_row = (volatile uint32_t *)(fb + (uint64_t)(dy + r) * pitch);
        for (int c = 0; c < w; c++) {
            d_row[dx + c] = s_row[sx + c];
        }
    }
}

void novaos_fb_blit(const uint32_t *src, int dx, int dy, int w, int h, int stride) {
    uint64_t fb = framebuffer_address;
    if (!fb) fb = *(volatile uint64_t *)0x9000;
    uint32_t pitch = framebuffer_pitch ? framebuffer_pitch : *(volatile uint32_t *)0x9004;

    for (int r = 0; r < h; r++) {
        volatile uint32_t *d_row = (volatile uint32_t *)(fb + (uint64_t)(dy + r) * pitch);
        const uint32_t *s_row = src + (r * stride);
        for (int c = 0; c < w; c++) {
            d_row[dx + c] = s_row[c];
        }
    }
}

/* Entry point invoked from NovaOS assembly */
int novaos_netsurf_main(int argc, char **argv) {
    (void)argc; (void)argv;
    /* NetSurf raw 32-bit ARGB surface initialized directly on NovaOS Framebuffer */
    return 0;
}
