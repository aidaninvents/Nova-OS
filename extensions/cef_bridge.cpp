// ==============================================================================
// NovaOS Extension Module 3: CEF Off-Screen Bridging Implementation
// Target: Bare-Metal C++ for NovaOS
// ==============================================================================

#include "cef_bridge.hpp"
#include <cstring>

NovaCefWindowBridge::NovaCefWindowBridge(int screen_x, int screen_y, int width, int height)
    : screen_x_(screen_x),
      screen_y_(screen_y),
      width_(width),
      height_(height),
      buffer_size_bytes_(0),
      shared_buffer_(nullptr),
      has_new_frame_(false) {
}

NovaCefWindowBridge::~NovaCefWindowBridge() {
    if (shared_buffer_ && buffer_size_bytes_ > 0) {
        NovaOS_POSIX::sys_munmap(shared_buffer_, buffer_size_bytes_);
        shared_buffer_ = nullptr;
    }
}

bool NovaCefWindowBridge::Initialize() {
    // 1. Initialize hardware GPU pipeline (VirtualBox SVGA / Real MMIO / LFB)
    gpu_pack_detect_and_install();

    // 2. Allocate contiguous 32-bpp RGBA shared RAM pool via kernel mmap syscall
    buffer_size_bytes_ = static_cast<size_t>(width_) * height_ * 4;
    shared_buffer_ = static_cast<uint8_t*>(
        NovaOS_POSIX::sys_mmap(
            nullptr,
            buffer_size_bytes_,
            0x3,  // PROT_READ | PROT_WRITE
            0x22, // MAP_PRIVATE | MAP_ANONYMOUS
            -1,
            0
        )
    );

    if (!shared_buffer_ || reinterpret_cast<int64_t>(shared_buffer_) < 0) {
        shared_buffer_ = nullptr;
        return false;
    }

    // Initialize to solid background
    std::memset(shared_buffer_, 0x1E, buffer_size_bytes_);
    has_new_frame_ = true;
    return true;
}

void NovaCefWindowBridge::Resize(int new_width, int new_height) {
    if (new_width <= 0 || new_height <= 0) return;

    if (shared_buffer_) {
        NovaOS_POSIX::sys_munmap(shared_buffer_, buffer_size_bytes_);
    }

    width_ = new_width;
    height_ = new_height;
    buffer_size_bytes_ = static_cast<size_t>(width_) * height_ * 4;
    shared_buffer_ = static_cast<uint8_t*>(
        NovaOS_POSIX::sys_mmap(
            nullptr,
            buffer_size_bytes_,
            0x3,
            0x22,
            -1,
            0
        )
    );
    has_new_frame_ = true;
}

void NovaCefWindowBridge::OnBufferPainted(const uint8_t* buffer, int width, int height, const NovaCefRect* dirty_rects, size_t dirty_count) {
    if (!shared_buffer_ || !buffer || width != width_ || height != height_) return;

    // Direct dirty-rectangle update into shared buffer and immediate AVX2 blit to LFB
    if (dirty_rects && dirty_count > 0) {
        for (size_t i = 0; i < dirty_count; ++i) {
            const NovaCefRect& r = dirty_rects[i];
            if (r.width <= 0 || r.height <= 0) continue;

            const uint8_t* src_sub = buffer + (r.y * width * 4) + (r.x * 4);
            uint8_t* dst_sub = shared_buffer_ + (r.y * width * 4) + (r.x * 4);

            // Copy to shared buffer
            for (int row = 0; row < r.height; ++row) {
                std::memcpy(dst_sub + row * width * 4, src_sub + row * width * 4, r.width * 4);
            }

            // Blit dirty rect directly to active LFB coordinates
            gpu_pack_blit_avx2(
                src_sub,
                screen_x_ + r.x,
                screen_y_ + r.y,
                r.width,
                r.height,
                width * 4
            );
        }
    } else {
        // Full surface paint
        std::memcpy(shared_buffer_, buffer, buffer_size_bytes_);
        gpu_pack_blit_avx2(
            shared_buffer_,
            screen_x_,
            screen_y_,
            width_,
            height_,
            width_ * 4
        );
    }
    has_new_frame_ = false;
}

void NovaCefWindowBridge::RenderTick60Hz() {
    if (!has_new_frame_ || !shared_buffer_) return;

    // Full frame scanout to Linear Framebuffer: Offset = (Y * Pitch) + (X * 4)
    gpu_pack_blit_avx2(
        shared_buffer_,
        screen_x_,
        screen_y_,
        width_,
        height_,
        width_ * 4
    );
    has_new_frame_ = false;
}

// ------------------------------------------------------------------------------
// C ABI Exports for Assembly Kernel Linkage
// ------------------------------------------------------------------------------
extern "C" {
    NovaCefWindowBridge* novaos_cef_bridge_create(int x, int y, int w, int h) {
        auto* bridge = new NovaCefWindowBridge(x, y, w, h);
        if (!bridge->Initialize()) {
            delete bridge;
            return nullptr;
        }
        return bridge;
    }

    void novaos_cef_bridge_paint(NovaCefWindowBridge* bridge, const uint8_t* pixels, int w, int h) {
        if (bridge) {
            bridge->OnBufferPainted(pixels, w, h, nullptr, 0);
        }
    }

    void novaos_cef_bridge_tick_60hz(NovaCefWindowBridge* bridge) {
        if (bridge) {
            bridge->RenderTick60Hz();
        }
    }

    void novaos_cef_bridge_destroy(NovaCefWindowBridge* bridge) {
        delete bridge;
    }
}
