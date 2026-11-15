#include "browser_bridge.h"
#include "nova_container.h"
#include <litehtml.h>

namespace {

nova::NovaContainer*   g_container = nullptr;
litehtml::document::ptr g_document;
uint32_t               g_vp_w      = 1024;
uint32_t               g_vp_h      = 768;
int32_t                g_scroll_x  = 0;
int32_t                g_scroll_y  = 0;

void noop_redraw(const litehtml::position&) {}

} // namespace

extern "C" int browser_init(uint32_t viewport_w, uint32_t viewport_h) {
    g_vp_w = viewport_w ? viewport_w : 1024;
    g_vp_h = viewport_h ? viewport_h : 768;
    g_scroll_x = 0;
    g_scroll_y = 0;

    if (!g_container) {
        g_container = new nova::NovaContainer(g_vp_w, g_vp_h);
    } else {
        g_container->set_viewport(g_vp_w, g_vp_h);
    }
    return g_container ? 0 : -1;
}

extern "C" int browser_load_html(const char* html, const char* base_url) {
    if (!g_container) {
        if (browser_init(g_vp_w, g_vp_h) != 0) return -1;
    }
    if (!html) return -1;

    g_container->clear_pending_url();
    if (base_url && *base_url) {
        g_container->set_base_url(base_url);
    } else {
        g_container->set_base_url("");
    }

    g_scroll_x = 0;
    g_scroll_y = 0;

    g_document = litehtml::document::createFromString(html, g_container);
    if (!g_document) return -2;

    g_document->render(litehtml::pixel_t(static_cast<float>(g_vp_w)));
    return 0;
}

extern "C" void browser_render(int32_t scroll_x, int32_t scroll_y) {
    if (!g_container || !g_document) return;
    g_scroll_x = scroll_x;
    g_scroll_y = scroll_y;

    litehtml::position clip(
        0, 0,
        litehtml::pixel_t(static_cast<float>(g_vp_w)),
        litehtml::pixel_t(static_cast<float>(g_vp_h))
    );
    ::set_clip_rect(0, 0, static_cast<int32_t>(g_vp_w), static_cast<int32_t>(g_vp_h));
    ::draw_rect(0, 0, static_cast<int32_t>(g_vp_w), static_cast<int32_t>(g_vp_h), 0xFFFFFFFFu);

    g_document->draw(
        0,
        static_cast<litehtml::pixel_t>(-g_scroll_x),
        static_cast<litehtml::pixel_t>(-g_scroll_y),
        &clip
    );
}

extern "C" int browser_on_click(int32_t x, int32_t y) {
    if (!g_container || !g_document) return 0;

    g_container->clear_pending_url();
    litehtml::pixel_t doc_x = static_cast<litehtml::pixel_t>(x + g_scroll_x);
    litehtml::pixel_t doc_y = static_cast<litehtml::pixel_t>(y + g_scroll_y);
    litehtml::pixel_t cli_x = static_cast<litehtml::pixel_t>(x);
    litehtml::pixel_t cli_y = static_cast<litehtml::pixel_t>(y);

    bool handled = false;
    if (g_document->on_lbutton_down(doc_x, doc_y, cli_x, cli_y, noop_redraw)) {
        handled = true;
    }
    if (g_document->on_lbutton_up(doc_x, doc_y, cli_x, cli_y, noop_redraw)) {
        handled = true;
    }

    const char* next_url = g_container->pending_url();
    if (next_url && *next_url) {
        size_t len = 0;
        char* page = ::https_fetch(next_url, &len);
        if (page) {
            browser_load_html(page, next_url);
            ::free(page);
            return 1;
        }
        return 1;
    }
    return handled ? 1 : 0;
}

extern "C" int32_t browser_scroll(int32_t delta_y) {
    if (!g_document) return g_scroll_y;
    int32_t doc_h = static_cast<int32_t>(g_document->height());
    int32_t max_y = doc_h - static_cast<int32_t>(g_vp_h);
    if (max_y < 0) max_y = 0;

    g_scroll_y += delta_y;
    if (g_scroll_y < 0) g_scroll_y = 0;
    if (g_scroll_y > max_y) g_scroll_y = max_y;
    return g_scroll_y;
}

extern "C" const char* browser_get_pending_url(void) {
    return g_container ? g_container->pending_url() : nullptr;
}

extern "C" void browser_clear_pending_url(void) {
    if (g_container) g_container->clear_pending_url();
}

extern "C" int browser_start_oauth(const char* client_id, const char* redirect_uri) {
    if (!client_id || !*client_id || !redirect_uri || !*redirect_uri) return -1;
    std::string url = "https://accounts.google.com/o/oauth2/v2/auth?client_id=";
    url += client_id;
    url += "&redirect_uri=";
    url += redirect_uri;
    url += "&response_type=code&scope=openid%20email%20profile%20https://www.googleapis.com/auth/youtube.readonly"
           "&access_type=offline&prompt=consent";

    size_t len = 0;
    char* page = ::https_fetch(url.c_str(), &len);
    if (!page) return -2;
    int rc = browser_load_html(page, url.c_str());
    ::free(page);
    return rc;
}
