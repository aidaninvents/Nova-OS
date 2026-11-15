// ==============================================================================
// NovaOS Extension Module 3: CEF Off-Screen Bridging Header
// Provides stripped-down POSIX translation shims for NovaOS x86-64 Kernel
// and CefRenderHandler OSR (Off-Screen Rendering) to shared RAM buffer
// ==============================================================================

#pragma once

#include <cstdint>
#include <cstddef>

// ------------------------------------------------------------------------------
// Assembly Kernel Syscall / Function Interfaces (Module 2 AVX2 Blitter)
// ------------------------------------------------------------------------------
extern "C" {
    // High-performance AVX2 Framebuffer Blitter (Offset = Y * Pitch + X * 4)
    void gpu_pack_blit_avx2(
        const uint8_t* src_rgba,
        uint64_t dest_x,
        uint64_t dest_y,
        uint64_t width,
        uint64_t height,
        uint64_t src_stride
    );

    // Hardware GPU Installer Probe
    int32_t gpu_pack_detect_and_install();
}

// ------------------------------------------------------------------------------
// Lightweight POSIX Emulation Shims for Bare-Metal NovaOS
// Routes memory allocation, threading, and file operations to syscall instruction
// ------------------------------------------------------------------------------
namespace NovaOS_POSIX {

    inline void* sys_mmap(void* addr, size_t length, int prot, int flags, int fd, int64_t offset) {
        register int64_t rax __asm__("rax") = 9;  // sys_mmap
        register void*   rdi __asm__("rdi") = addr;
        register size_t  rsi __asm__("rsi") = length;
        register int32_t rdx __asm__("rdx") = prot;
        register int32_t r10 __asm__("r10") = flags;
        register int32_t r8  __asm__("r8")  = fd;
        register int64_t r9  __asm__("r9")  = offset;
        __asm__ __volatile__(
            "syscall"
            : "+r"(rax)
            : "r"(rdi), "r"(rsi), "r"(rdx), "r"(r10), "r"(r8), "r"(r9)
            : "rcx", "r11", "memory"
        );
        return reinterpret_cast<void*>(rax);
    }

    inline int sys_munmap(void* addr, size_t length) {
        register int64_t rax __asm__("rax") = 11; // sys_munmap
        register void*   rdi __asm__("rdi") = addr;
        register size_t  rsi __asm__("rsi") = length;
        __asm__ __volatile__(
            "syscall"
            : "+r"(rax)
            : "r"(rdi), "r"(rsi)
            : "rcx", "r11", "memory"
        );
        return static_cast<int>(rax);
    }

    inline int sys_futex(int* uaddr, int futex_op, int val, const void* timeout) {
        register int64_t rax __asm__("rax") = 202; // sys_futex
        register int*    rdi __asm__("rdi") = uaddr;
        register int     rsi __asm__("rsi") = futex_op;
        register int     rdx __asm__("rdx") = val;
        register const void* r10 __asm__("r10") = timeout;
        __asm__ __volatile__(
            "syscall"
            : "+r"(rax)
            : "r"(rdi), "r"(rsi), "r"(rdx), "r"(r10)
            : "rcx", "r11", "memory"
        );
        return static_cast<int>(rax);
    }

    inline void sys_sched_yield() {
        register int64_t rax __asm__("rax") = 24; // sys_sched_yield
        __asm__ __volatile__("syscall" : "+r"(rax) : : "rcx", "r11", "memory");
    }
}

// ------------------------------------------------------------------------------
// Off-Screen Shared Memory Surface Description
// ------------------------------------------------------------------------------
struct NovaCefRect {
    int x;
    int y;
    int width;
    int height;
};

class NovaCefRenderListener {
public:
    virtual ~NovaCefRenderListener() = default;
    virtual void OnBufferPainted(const uint8_t* buffer, int width, int height, const NovaCefRect* dirty_rects, size_t dirty_count) = 0;
};

// ------------------------------------------------------------------------------
// CEF Off-Screen Window Controller Interface
// ------------------------------------------------------------------------------
class NovaCefWindowBridge : public NovaCefRenderListener {
public:
    NovaCefWindowBridge(int screen_x, int screen_y, int width, int height);
    ~NovaCefWindowBridge() override;

    bool Initialize();
    void Resize(int new_width, int new_height);
    void RenderTick60Hz();

    // NovaCefRenderListener
    void OnBufferPainted(const uint8_t* buffer, int width, int height, const NovaCefRect* dirty_rects, size_t dirty_count) override;

    uint8_t* GetSharedBuffer() const { return shared_buffer_; }
    int GetWidth() const { return width_; }
    int GetHeight() const { return height_; }
    int GetX() const { return screen_x_; }
    int GetY() const { return screen_y_; }

private:
    int screen_x_;
    int screen_y_;
    int width_;
    int height_;
    size_t buffer_size_bytes_;
    uint8_t* shared_buffer_;
    bool has_new_frame_;
};
