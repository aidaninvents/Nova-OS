#ifndef NOVA_CONTAINER_H
#define NOVA_CONTAINER_H

#include "browser_bridge.h"
#include <litehtml.h>

namespace nova {

struct NovaFont {
    uint32_t size_px;
    int      weight;
    bool     italic;
};

struct ClipEntry {
    int32_t x;
    int32_t y;
    int32_t w;
    int32_t h;
};

class NovaContainer : public litehtml::document_container {
public:
    NovaContainer(uint32_t viewport_w, uint32_t viewport_h);
    ~NovaContainer() override = default;

    void set_viewport(uint32_t w, uint32_t h);
    const char* pending_url() const { return m_pending_url.empty() ? nullptr : m_pending_url.c_str(); }
    void clear_pending_url() { m_pending_url.clear(); }

    /* Font management */
    litehtml::uint_ptr create_font(const litehtml::font_description& descr,
                                   const litehtml::document* doc,
                                   litehtml::font_metrics* fm) override;
    void               delete_font(litehtml::uint_ptr hFont) override;
    litehtml::pixel_t  text_width(const char* text, litehtml::uint_ptr hFont) override;
    void               draw_text(litehtml::uint_ptr hdc, const char* text,
                                 litehtml::uint_ptr hFont, litehtml::web_color color,
                                 const litehtml::position& pos) override;
    litehtml::pixel_t  pt_to_px(float pt) const override;
    litehtml::pixel_t  get_default_font_size() const override;
    const char*        get_default_font_name() const override;

    /* Drawing callbacks */
    void draw_list_marker(litehtml::uint_ptr hdc, const litehtml::list_marker& marker) override;
    void load_image(const char* src, const char* baseurl, bool redraw_on_ready) override;
    void get_image_size(const char* src, const char* baseurl, litehtml::size& sz) override;
    void draw_image(litehtml::uint_ptr hdc, const litehtml::background_layer& layer,
                    const std::string& url, const std::string& base_url) override;
    void draw_solid_fill(litehtml::uint_ptr hdc, const litehtml::background_layer& layer,
                         const litehtml::web_color& color) override;
    void draw_linear_gradient(litehtml::uint_ptr hdc, const litehtml::background_layer& layer,
                              const litehtml::background_layer::linear_gradient& gradient) override;
    void draw_radial_gradient(litehtml::uint_ptr hdc, const litehtml::background_layer& layer,
                              const litehtml::background_layer::radial_gradient& gradient) override;
    void draw_conic_gradient(litehtml::uint_ptr hdc, const litehtml::background_layer& layer,
                             const litehtml::background_layer::conic_gradient& gradient) override;
    void draw_borders(litehtml::uint_ptr hdc, const litehtml::borders& borders,
                      const litehtml::position& draw_pos, bool root) override;

    /* Document & interaction callbacks */
    void set_caption(const char* caption) override;
    void set_base_url(const char* base_url) override;
    void link(const std::shared_ptr<litehtml::document>& doc,
              const litehtml::element::ptr& el) override;
    void on_anchor_click(const char* url, const litehtml::element::ptr& el) override;
    void on_mouse_event(const litehtml::element::ptr& el, litehtml::mouse_event event) override;
    void set_cursor(const char* cursor) override;
    void transform_text(std::string& text, litehtml::text_transform tt) override;
    void import_css(std::string& text, const std::string& url, std::string& baseurl) override;
    void set_clip(const litehtml::position& pos, const litehtml::border_radiuses& bdr_radius) override;
    void del_clip() override;
    void get_viewport(litehtml::position& viewport) const override;
    litehtml::element::ptr create_element(const char* tag_name,
                                          const litehtml::string_map& attributes,
                                          const std::shared_ptr<litehtml::document>& doc) override;
    void get_media_features(litehtml::media_features& media) const override;
    void get_language(std::string& language, std::string& culture) const override;

    /* Helper for legacy draw_background-style solid/border fills */
    void draw_background(litehtml::uint_ptr hdc, const litehtml::background_layer& layer,
                         const litehtml::web_color& color);

private:
    static uint32_t to_argb(const litehtml::web_color& c);
    std::string resolve_url(const char* url, const char* base_url) const;

    uint32_t               m_vp_w;
    uint32_t               m_vp_h;
    std::string            m_base_url;
    std::string            m_pending_url;
    std::vector<ClipEntry> m_clip_stack;
};

} // namespace nova

#endif /* NOVA_CONTAINER_H */
