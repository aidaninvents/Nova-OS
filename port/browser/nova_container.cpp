#include "nova_container.h"
#include <cstring>

namespace nova {

NovaContainer::NovaContainer(uint32_t viewport_w, uint32_t viewport_h)
    : m_vp_w(viewport_w ? viewport_w : 1024),
      m_vp_h(viewport_h ? viewport_h : 768) {
}

void NovaContainer::set_viewport(uint32_t w, uint32_t h) {
    if (w) m_vp_w = w;
    if (h) m_vp_h = h;
}

uint32_t NovaContainer::to_argb(const litehtml::web_color& c) {
    return (static_cast<uint32_t>(c.alpha) << 24) |
           (static_cast<uint32_t>(c.red)   << 16) |
           (static_cast<uint32_t>(c.green) << 8)  |
            static_cast<uint32_t>(c.blue);
}

std::string NovaContainer::resolve_url(const char* url, const char* base_url) const {
    if (!url || !*url) return {};
    std::string u(url);
    if (u.find("://") != std::string::npos || u.rfind("data:", 0) == 0) {
        return u;
    }
    const std::string& base = (base_url && *base_url) ? std::string(base_url) : m_base_url;
    if (base.empty()) return u;

    if (u.rfind("//", 0) == 0) {
        size_t pos = base.find("://");
        if (pos != std::string::npos) {
            return base.substr(0, pos + 1) + u;
        }
        return "https:" + u;
    }
    if (u[0] == '/') {
        size_t scheme = base.find("://");
        if (scheme != std::string::npos) {
            size_t slash = base.find('/', scheme + 3);
            if (slash != std::string::npos) {
                return base.substr(0, slash) + u;
            }
            return base + u;
        }
        return u;
    }
    size_t last_slash = base.rfind('/');
    if (last_slash != std::string::npos) {
        return base.substr(0, last_slash + 1) + u;
    }
    return base + "/" + u;
}

/* =========================================================================
 * Font Management
 * ========================================================================= */
litehtml::uint_ptr NovaContainer::create_font(const litehtml::font_description& descr,
                                              const litehtml::document* /*doc*/,
                                              litehtml::font_metrics* fm) {
    uint32_t sz = static_cast<uint32_t>(descr.size.value() > 0.0f ? descr.size.value() : 16.0f);
    if (sz < 8) sz = 8;

    auto* f = static_cast<NovaFont*>(::malloc(sizeof(NovaFont)));
    if (!f) return 0;
    f->size_px = sz;
    f->weight  = descr.weight;
    f->italic  = (descr.style == litehtml::font_style_italic);

    if (fm) {
        int ascent  = static_cast<int>((sz * 4) / 5);
        int descent = static_cast<int>(sz) - ascent;
        fm->font_size   = litehtml::pixel_t(static_cast<float>(sz));
        fm->height      = litehtml::pixel_t(static_cast<float>(sz));
        fm->ascent      = litehtml::pixel_t(ascent);
        fm->descent     = litehtml::pixel_t(descent);
        fm->x_height    = litehtml::pixel_t(static_cast<float>(sz / 2));
        fm->ch_width    = litehtml::pixel_t(static_cast<float>((sz * 8) / 16));
        fm->draw_spaces = true;
    }
    return reinterpret_cast<litehtml::uint_ptr>(f);
}

void NovaContainer::delete_font(litehtml::uint_ptr hFont) {
    if (hFont) {
        ::free(reinterpret_cast<void*>(hFont));
    }
}

litehtml::pixel_t NovaContainer::text_width(const char* text, litehtml::uint_ptr hFont) {
    if (!text) return 0;
    uint32_t sz = 16;
    if (hFont) {
        sz = reinterpret_cast<NovaFont*>(hFont)->size_px;
    }
    uint32_t char_w = (sz * 8) / 16;
    if (char_w < 5) char_w = 5;
    size_t len = std::strlen(text);
    return static_cast<litehtml::pixel_t>(static_cast<float>(len * char_w));
}

void NovaContainer::draw_text(litehtml::uint_ptr /*hdc*/, const char* text,
                              litehtml::uint_ptr hFont, litehtml::web_color color,
                              const litehtml::position& pos) {
    if (!text || !*text || color.alpha == 0) return;
    uint32_t sz = 16;
    if (hFont) {
        sz = reinterpret_cast<NovaFont*>(hFont)->size_px;
    }
    ::draw_text(static_cast<int32_t>(pos.x),
                static_cast<int32_t>(pos.y),
                text,
                to_argb(color),
                sz);
}

litehtml::pixel_t NovaContainer::pt_to_px(float pt) const {
    return static_cast<litehtml::pixel_t>((pt * 96.0f) / 72.0f);
}

litehtml::pixel_t NovaContainer::get_default_font_size() const {
    return static_cast<litehtml::pixel_t>(16);
}

const char* NovaContainer::get_default_font_name() const {
    return "NovaSans";
}

/* =========================================================================
 * Backgrounds, Images & Borders
 * ========================================================================= */
void NovaContainer::draw_list_marker(litehtml::uint_ptr /*hdc*/,
                                     const litehtml::list_marker& marker) {
    if (marker.color.alpha == 0) return;
    int32_t x = static_cast<int32_t>(marker.pos.x);
    int32_t y = static_cast<int32_t>(marker.pos.y);
    int32_t w = static_cast<int32_t>(marker.pos.width);
    int32_t h = static_cast<int32_t>(marker.pos.height);
    if (w < 4) w = 4;
    if (h < 4) h = 4;
    ::draw_rect(x, y, w, h, to_argb(marker.color));
}

void NovaContainer::load_image(const char* /*src*/, const char* /*baseurl*/, bool /*redraw_on_ready*/) {
    /* Images are fetched synchronously or cached by Nova OS image decoder */
}

void NovaContainer::get_image_size(const char* /*src*/, const char* /*baseurl*/, litehtml::size& sz) {
    /* Default placeholder dimensions when image metadata is not pre-cached */
    sz.width  = 0;
    sz.height = 0;
}

void NovaContainer::draw_background(litehtml::uint_ptr /*hdc*/,
                                    const litehtml::background_layer& layer,
                                    const litehtml::web_color& color) {
    if (color.alpha == 0) return;
    int32_t x = static_cast<int32_t>(layer.border_box.x);
    int32_t y = static_cast<int32_t>(layer.border_box.y);
    int32_t w = static_cast<int32_t>(layer.border_box.width);
    int32_t h = static_cast<int32_t>(layer.border_box.height);
    if (w > 0 && h > 0) {
        ::draw_rect(x, y, w, h, to_argb(color));
    }
}

void NovaContainer::draw_solid_fill(litehtml::uint_ptr hdc,
                                    const litehtml::background_layer& layer,
                                    const litehtml::web_color& color) {
    draw_background(hdc, layer, color);
}

void NovaContainer::draw_image(litehtml::uint_ptr /*hdc*/,
                               const litehtml::background_layer& layer,
                               const std::string& url,
                               const std::string& base_url) {
    std::string full = resolve_url(url.c_str(), base_url.c_str());
    if (full.empty()) return;

    size_t len = 0;
    char* raw = ::https_fetch(full.c_str(), &len);
    if (!raw) return;

    int32_t x = static_cast<int32_t>(layer.origin_box.x);
    int32_t y = static_cast<int32_t>(layer.origin_box.y);
    int32_t w = static_cast<int32_t>(layer.origin_box.width);
    int32_t h = static_cast<int32_t>(layer.origin_box.height);
    if (w > 0 && h > 0 && len >= static_cast<size_t>(w) * static_cast<size_t>(h) * 4) {
        ::draw_image(x, y, w, h, reinterpret_cast<const uint32_t*>(raw));
    }
    ::free(raw);
}

void NovaContainer::draw_linear_gradient(litehtml::uint_ptr hdc,
                                         const litehtml::background_layer& layer,
                                         const litehtml::background_layer::linear_gradient& gradient) {
    if (!gradient.color_points.empty()) {
        draw_background(hdc, layer, gradient.color_points.front().color);
    }
}

void NovaContainer::draw_radial_gradient(litehtml::uint_ptr hdc,
                                         const litehtml::background_layer& layer,
                                         const litehtml::background_layer::radial_gradient& gradient) {
    if (!gradient.color_points.empty()) {
        draw_background(hdc, layer, gradient.color_points.front().color);
    }
}

void NovaContainer::draw_conic_gradient(litehtml::uint_ptr hdc,
                                        const litehtml::background_layer& layer,
                                        const litehtml::background_layer::conic_gradient& gradient) {
    if (!gradient.color_points.empty()) {
        draw_background(hdc, layer, gradient.color_points.front().color);
    }
}

void NovaContainer::draw_borders(litehtml::uint_ptr /*hdc*/,
                                 const litehtml::borders& borders,
                                 const litehtml::position& draw_pos,
                                 bool /*root*/) {
    int32_t x = static_cast<int32_t>(draw_pos.x);
    int32_t y = static_cast<int32_t>(draw_pos.y);
    int32_t w = static_cast<int32_t>(draw_pos.width);
    int32_t h = static_cast<int32_t>(draw_pos.height);
    if (w <= 0 || h <= 0) return;

    int32_t bt = static_cast<int32_t>(borders.top.width);
    int32_t bb = static_cast<int32_t>(borders.bottom.width);
    int32_t bl = static_cast<int32_t>(borders.left.width);
    int32_t br = static_cast<int32_t>(borders.right.width);

    if (bt > 0 && borders.top.style > litehtml::border_style_hidden && borders.top.color.alpha > 0) {
        ::draw_rect(x, y, w, bt, to_argb(borders.top.color));
    }
    if (bb > 0 && borders.bottom.style > litehtml::border_style_hidden && borders.bottom.color.alpha > 0) {
        ::draw_rect(x, y + h - bb, w, bb, to_argb(borders.bottom.color));
    }
    if (bl > 0 && borders.left.style > litehtml::border_style_hidden && borders.left.color.alpha > 0) {
        ::draw_rect(x, y, bl, h, to_argb(borders.left.color));
    }
    if (br > 0 && borders.right.style > litehtml::border_style_hidden && borders.right.color.alpha > 0) {
        ::draw_rect(x + w - br, y, br, h, to_argb(borders.right.color));
    }
}

/* =========================================================================
 * Document, CSS Import, Clipping & Click Callbacks
 * ========================================================================= */
void NovaContainer::set_caption(const char* /*caption*/) {
}

void NovaContainer::set_base_url(const char* base_url) {
    m_base_url = base_url ? base_url : "";
}

void NovaContainer::link(const std::shared_ptr<litehtml::document>& /*doc*/,
                         const litehtml::element::ptr& /*el*/) {
}

void NovaContainer::on_anchor_click(const char* url, const litehtml::element::ptr& /*el*/) {
    if (url && *url) {
        m_pending_url = resolve_url(url, m_base_url.c_str());
    }
}

void NovaContainer::on_mouse_event(const litehtml::element::ptr& /*el*/,
                                   litehtml::mouse_event /*event*/) {
}

void NovaContainer::set_cursor(const char* /*cursor*/) {
}

void NovaContainer::transform_text(std::string& text, litehtml::text_transform tt) {
    if (tt == litehtml::text_transform_uppercase) {
        for (char& ch : text) {
            if (ch >= 'a' && ch <= 'z') ch = static_cast<char>(ch - 'a' + 'A');
        }
    } else if (tt == litehtml::text_transform_lowercase) {
        for (char& ch : text) {
            if (ch >= 'A' && ch <= 'Z') ch = static_cast<char>(ch - 'A' + 'a');
        }
    } else if (tt == litehtml::text_transform_capitalize) {
        bool cap_next = true;
        for (char& ch : text) {
            if (ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r') {
                cap_next = true;
            } else if (cap_next) {
                if (ch >= 'a' && ch <= 'z') ch = static_cast<char>(ch - 'a' + 'A');
                cap_next = false;
            }
        }
    }
}

void NovaContainer::import_css(std::string& text, const std::string& url, std::string& baseurl) {
    std::string full = resolve_url(url.c_str(), baseurl.c_str());
    if (full.empty()) return;

    size_t len = 0;
    char* css_buf = ::https_fetch(full.c_str(), &len);
    if (css_buf) {
        text.assign(css_buf, len ? len : std::strlen(css_buf));
        baseurl = full;
        ::free(css_buf);
    }
}

void NovaContainer::set_clip(const litehtml::position& pos,
                             const litehtml::border_radiuses& /*bdr_radius*/) {
    ClipEntry ce{
        static_cast<int32_t>(pos.x),
        static_cast<int32_t>(pos.y),
        static_cast<int32_t>(pos.width),
        static_cast<int32_t>(pos.height)
    };
    if (!m_clip_stack.empty()) {
        const ClipEntry& prev = m_clip_stack.back();
        int32_t x1 = (ce.x > prev.x) ? ce.x : prev.x;
        int32_t y1 = (ce.y > prev.y) ? ce.y : prev.y;
        int32_t x2 = ((ce.x + ce.w) < (prev.x + prev.w)) ? (ce.x + ce.w) : (prev.x + prev.w);
        int32_t y2 = ((ce.y + ce.h) < (prev.y + prev.h)) ? (ce.y + ce.h) : (prev.y + prev.h);
        ce.x = x1;
        ce.y = y1;
        ce.w = (x2 > x1) ? (x2 - x1) : 0;
        ce.h = (y2 > y1) ? (y2 - y1) : 0;
    }
    m_clip_stack.push_back(ce);
    ::set_clip_rect(ce.x, ce.y, ce.w, ce.h);
}

void NovaContainer::del_clip() {
    if (!m_clip_stack.empty()) {
        m_clip_stack.pop_back();
    }
    if (!m_clip_stack.empty()) {
        const ClipEntry& top = m_clip_stack.back();
        ::set_clip_rect(top.x, top.y, top.w, top.h);
    } else {
        ::set_clip_rect(0, 0, static_cast<int32_t>(m_vp_w), static_cast<int32_t>(m_vp_h));
    }
}

void NovaContainer::get_viewport(litehtml::position& viewport) const {
    viewport.x      = 0;
    viewport.y      = 0;
    viewport.width  = litehtml::pixel_t(static_cast<float>(m_vp_w));
    viewport.height = litehtml::pixel_t(static_cast<float>(m_vp_h));
}

litehtml::element::ptr NovaContainer::create_element(const char* /*tag_name*/,
                                                     const litehtml::string_map& /*attributes*/,
                                                     const std::shared_ptr<litehtml::document>& /*doc*/) {
    return nullptr;
}

void NovaContainer::get_media_features(litehtml::media_features& media) const {
    media.type          = litehtml::media_type_screen;
    media.width         = litehtml::pixel_t(static_cast<float>(m_vp_w));
    media.height        = litehtml::pixel_t(static_cast<float>(m_vp_h));
    media.device_width  = litehtml::pixel_t(static_cast<float>(m_vp_w));
    media.device_height = litehtml::pixel_t(static_cast<float>(m_vp_h));
    media.color         = 8;
    media.color_index   = 0;
    media.monochrome    = 0;
    media.resolution    = 96;
}

void NovaContainer::get_language(std::string& language, std::string& culture) const {
    language = "en";
    culture  = "US";
}

} // namespace nova
