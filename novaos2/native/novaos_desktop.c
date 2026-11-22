#include <gtk/gtk.h>
#include <webkit2/webkit2.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>

static GtkWidget *g_main_win = NULL;

typedef struct {
    GtkWidget *win;
    GtkWidget *title_lbl;
    GtkWidget *url_entry;
    GtkWidget *status_lbl;
    GtkWidget *notebook;
    gboolean is_maximized;
    gboolean dragging;
    gdouble drag_start_x;
    gdouble drag_start_y;
    gint win_start_x;
    gint win_start_y;
} NovaBrowserWin;

static WebKitWebView *get_current_webview(NovaBrowserWin *bw) {
    gint idx = gtk_notebook_get_current_page(GTK_NOTEBOOK(bw->notebook));
    if (idx < 0) return NULL;
    return WEBKIT_WEB_VIEW(gtk_notebook_get_nth_page(GTK_NOTEBOOK(bw->notebook), idx));
}

static void on_uri_changed(WebKitWebView *wv, GParamSpec *pspec, NovaBrowserWin *bw) {
    if (wv == get_current_webview(bw)) {
        const gchar *uri = webkit_web_view_get_uri(wv);
        if (uri) gtk_entry_set_text(GTK_ENTRY(bw->url_entry), uri);
    }
}

static void on_title_changed(WebKitWebView *wv, GParamSpec *pspec, NovaBrowserWin *bw) {
    const gchar *t = webkit_web_view_get_title(wv);
    if (t && *t) {
        GtkWidget *tab_lbl = gtk_notebook_get_tab_label(GTK_NOTEBOOK(bw->notebook), GTK_WIDGET(wv));
        if (tab_lbl && GTK_IS_LABEL(tab_lbl)) {
            gchar *short_t = g_strndup(t, 24);
            gtk_label_set_text(GTK_LABEL(tab_lbl), short_t);
            g_free(short_t);
        }
    }
}

static void on_browser_load_changed(WebKitWebView *wv, WebKitLoadEvent ev, NovaBrowserWin *bw) {
    const gchar *uri = webkit_web_view_get_uri(wv);
    g_printerr("[BROWSER] load event: %d uri=%s\n", (int)ev, uri ? uri : "");
    if (bw && bw->status_lbl) {
        if (ev == WEBKIT_LOAD_STARTED || ev == WEBKIT_LOAD_COMMITTED) {
            gtk_label_set_text(GTK_LABEL(bw->status_lbl), "Loading...");
        } else if (ev == WEBKIT_LOAD_FINISHED) {
            gtk_label_set_text(GTK_LABEL(bw->status_lbl), "Ready (1080p HD)");
        }
    }
}

static gboolean on_browser_load_failed(WebKitWebView *wv, WebKitLoadEvent ev, gchar *failing_uri, GError *error, NovaBrowserWin *bw) {
    g_printerr("[BROWSER] load failed: uri=%s err=%s\n", failing_uri ? failing_uri : "", error ? error->message : "unknown");
    if (bw && bw->status_lbl) {
        gtk_label_set_text(GTK_LABEL(bw->status_lbl), error ? error->message : "Connection error");
    }
    return FALSE;
}

static NovaBrowserWin *g_browser_win = NULL;

static void on_download_finished(WebKitDownload *dl, gpointer data) {
    const gchar *dest = webkit_download_get_destination(dl);
    g_printerr("[BROWSER] Download finished: %s\n", dest ? dest : "(unknown)");
    if (g_browser_win && g_browser_win->status_lbl && GTK_IS_LABEL(g_browser_win->status_lbl)) {
        gchar *base = dest ? g_path_get_basename(dest) : g_strdup("file");
        gchar *msg = g_strdup_printf("Downloaded %s to Downloads/", base);
        gtk_label_set_text(GTK_LABEL(g_browser_win->status_lbl), msg);
        g_free(msg);
        g_free(base);
    }
}

static void on_download_failed(WebKitDownload *dl, GError *err, gpointer data) {
    g_printerr("[BROWSER] Download failed: %s\n", err ? err->message : "unknown");
    if (g_browser_win && g_browser_win->status_lbl && GTK_IS_LABEL(g_browser_win->status_lbl)) {
        gtk_label_set_text(GTK_LABEL(g_browser_win->status_lbl), err ? err->message : "Download failed");
    }
}

static gboolean on_download_decide_dest(WebKitDownload *dl, gchar *suggested_filename, gpointer data) {
    const gchar *dl_dir = "/opt/novaos2/storage/Downloads";
    g_mkdir_with_parents(dl_dir, 0755);
    const gchar *fname = (suggested_filename && *suggested_filename) ? suggested_filename : "download.bin";
    gchar *dest_path = g_build_filename(dl_dir, fname, NULL);
    gchar *dest_uri = g_filename_to_uri(dest_path, NULL, NULL);
    g_printerr("[BROWSER] Downloading to %s\n", dest_path);
    if (g_browser_win && g_browser_win->status_lbl && GTK_IS_LABEL(g_browser_win->status_lbl)) {
        gchar *msg = g_strdup_printf("Downloading %s...", fname);
        gtk_label_set_text(GTK_LABEL(g_browser_win->status_lbl), msg);
        g_free(msg);
    }
    webkit_download_set_destination(dl, dest_uri);
    g_free(dest_uri);
    g_free(dest_path);
    return TRUE;
}

static void on_download_started(WebKitWebContext *ctx, WebKitDownload *dl, gpointer data) {
    g_signal_connect(dl, "decide-destination", G_CALLBACK(on_download_decide_dest), NULL);
    g_signal_connect(dl, "finished", G_CALLBACK(on_download_finished), NULL);
    g_signal_connect(dl, "failed", G_CALLBACK(on_download_failed), NULL);
}

static void configure_webview_settings(WebKitWebView *wv) {
    WebKitSettings *st = webkit_web_view_get_settings(wv);
    webkit_settings_set_enable_javascript(st, TRUE);
    webkit_settings_set_enable_mediasource(st, TRUE);
    webkit_settings_set_enable_media_stream(st, TRUE);
    webkit_settings_set_enable_webaudio(st, TRUE);
    webkit_settings_set_enable_webgl(st, TRUE);
    webkit_settings_set_media_playback_requires_user_gesture(st, FALSE);
    webkit_settings_set_enable_developer_extras(st, TRUE);
    webkit_settings_set_enable_dns_prefetching(st, TRUE);
    webkit_settings_set_enable_page_cache(st, TRUE);
    webkit_settings_set_hardware_acceleration_policy(st, WEBKIT_HARDWARE_ACCELERATION_POLICY_NEVER);
    webkit_settings_set_user_agent(st,
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36");
}

static void add_browser_tab(NovaBrowserWin *bw, const gchar *url) {
    WebKitWebView *wv = WEBKIT_WEB_VIEW(webkit_web_view_new());
    configure_webview_settings(wv);
    g_signal_connect(wv, "notify::uri", G_CALLBACK(on_uri_changed), bw);
    g_signal_connect(wv, "notify::title", G_CALLBACK(on_title_changed), bw);
    g_signal_connect(wv, "load-changed", G_CALLBACK(on_browser_load_changed), bw);
    g_signal_connect(wv, "load-failed", G_CALLBACK(on_browser_load_failed), bw);

    GtkWidget *tab_lbl = gtk_label_new("New Tab");
    gtk_notebook_append_page(GTK_NOTEBOOK(bw->notebook), GTK_WIDGET(wv), tab_lbl);
    gtk_widget_show_all(GTK_WIDGET(wv));
    gint idx = gtk_notebook_page_num(GTK_NOTEBOOK(bw->notebook), GTK_WIDGET(wv));
    gtk_notebook_set_current_page(GTK_NOTEBOOK(bw->notebook), idx);
    webkit_web_view_load_uri(wv, url);
}

static void on_url_activate(GtkEntry *entry, NovaBrowserWin *bw) {
    const gchar *txt = gtk_entry_get_text(entry);
    if (!txt || !*txt) return;
    gchar *url = NULL;
    if (g_str_has_prefix(txt, "http://") || g_str_has_prefix(txt, "https://") || g_str_has_prefix(txt, "file://")) {
        url = g_strdup(txt);
    } else if (strchr(txt, '.') && !strchr(txt, ' ')) {
        url = g_strdup_printf("https://%s", txt);
    } else {
        gchar *esc = g_uri_escape_string(txt, NULL, FALSE);
        url = g_strdup_printf("https://www.google.com/search?q=%s", esc);
        g_free(esc);
    }
    WebKitWebView *wv = get_current_webview(bw);
    if (wv) webkit_web_view_load_uri(wv, url);
    g_free(url);
}

static void on_back(GtkButton *b, NovaBrowserWin *bw) {
    WebKitWebView *wv = get_current_webview(bw);
    if (wv && webkit_web_view_can_go_back(wv)) webkit_web_view_go_back(wv);
}
static void on_fwd(GtkButton *b, NovaBrowserWin *bw) {
    WebKitWebView *wv = get_current_webview(bw);
    if (wv && webkit_web_view_can_go_forward(wv)) webkit_web_view_go_forward(wv);
}
static void on_reload(GtkButton *b, NovaBrowserWin *bw) {
    WebKitWebView *wv = get_current_webview(bw);
    if (wv) webkit_web_view_reload(wv);
}
static void on_new_tab(GtkButton *b, NovaBrowserWin *bw) {
    add_browser_tab(bw, "https://www.google.com");
}
static void on_yt_btn(GtkButton *b, NovaBrowserWin *bw) {
    WebKitWebView *wv = get_current_webview(bw);
    if (wv) webkit_web_view_load_uri(wv, "https://www.youtube.com");
}
static void on_fast_btn(GtkButton *b, NovaBrowserWin *bw) {
    WebKitWebView *wv = get_current_webview(bw);
    if (wv) webkit_web_view_load_uri(wv, "https://fast.com");
}

static void on_win_min(GtkButton *b, NovaBrowserWin *bw) {
    gtk_window_iconify(GTK_WINDOW(bw->win));
}
static void on_win_max(GtkButton *b, NovaBrowserWin *bw) {
    if (bw->is_maximized) {
        gtk_window_resize(GTK_WINDOW(bw->win), 1380, 840);
        gtk_window_move(GTK_WINDOW(bw->win), 270, 70);
    } else {
        gtk_window_move(GTK_WINDOW(bw->win), 0, 0);
        gtk_window_resize(GTK_WINDOW(bw->win), 1920, 1004);
    }
    bw->is_maximized = !bw->is_maximized;
}
static void on_win_close(GtkButton *b, NovaBrowserWin *bw) {
    if (g_browser_win == bw) g_browser_win = NULL;
    gtk_widget_destroy(bw->win);
    g_free(bw);
}

static gboolean on_tb_press(GtkWidget *w, GdkEventButton *ev, NovaBrowserWin *bw) {
    if (ev->button == 1) {
        if (bw->is_maximized) {
            bw->is_maximized = FALSE;
            gtk_window_resize(GTK_WINDOW(bw->win), 1380, 840);
            gint nx = (gint)ev->x_root - 690;
            if (nx < 0) nx = 0;
            gtk_window_move(GTK_WINDOW(bw->win), nx, 10);
        }
        bw->dragging = TRUE;
        gtk_window_get_position(GTK_WINDOW(bw->win), &bw->win_start_x, &bw->win_start_y);
        bw->drag_start_x = ev->x_root;
        bw->drag_start_y = ev->y_root;
        gtk_window_begin_move_drag(GTK_WINDOW(bw->win), (gint)ev->button, (gint)ev->x_root, (gint)ev->y_root, ev->time);
        return TRUE;
    }
    return FALSE;
}
static gboolean on_tb_motion(GtkWidget *w, GdkEventMotion *ev, NovaBrowserWin *bw) {
    if (bw->dragging) {
        gint nx = bw->win_start_x + (gint)(ev->x_root - bw->drag_start_x);
        gint ny = bw->win_start_y + (gint)(ev->y_root - bw->drag_start_y);
        if (ny < 0) ny = 0;
        gtk_window_move(GTK_WINDOW(bw->win), nx, ny);
    }
    return FALSE;
}
static gboolean on_tb_release(GtkWidget *w, GdkEventButton *ev, NovaBrowserWin *bw) {
    bw->dragging = FALSE;
    return FALSE;
}

static void open_nova_browser(const gchar *title, const gchar *url, gboolean dark) {
    if (g_browser_win && GTK_IS_WIDGET(g_browser_win->win)) {
        add_browser_tab(g_browser_win, url);
        gtk_window_present(GTK_WINDOW(g_browser_win->win));
        return;
    }
    NovaBrowserWin *bw = g_new0(NovaBrowserWin, 1);
    g_browser_win = bw;
    bw->win = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_decorated(GTK_WINDOW(bw->win), FALSE);
    gtk_window_set_type_hint(GTK_WINDOW(bw->win), GDK_WINDOW_TYPE_HINT_NORMAL);
    gtk_window_set_default_size(GTK_WINDOW(bw->win), 1380, 840);
    gtk_window_move(GTK_WINDOW(bw->win), 270, 70);
    gtk_window_set_keep_above(GTK_WINDOW(bw->win), TRUE);

    GtkWidget *vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    gtk_container_add(GTK_CONTAINER(bw->win), vbox);

    /* Pill-shaped rounded Nova OS Title Bar */
    GtkWidget *evbox = gtk_event_box_new();
    gtk_widget_set_name(evbox, dark ? "nova-tb-dark" : "nova-tb-light");
    gtk_widget_set_size_request(evbox, -1, 44);
    gtk_widget_add_events(evbox, GDK_BUTTON_PRESS_MASK | GDK_BUTTON_RELEASE_MASK | GDK_POINTER_MOTION_MASK | GDK_BUTTON_MOTION_MASK);
    g_signal_connect(evbox, "button-press-event", G_CALLBACK(on_tb_press), bw);
    g_signal_connect(evbox, "motion-notify-event", G_CALLBACK(on_tb_motion), bw);
    g_signal_connect(evbox, "button-release-event", G_CALLBACK(on_tb_release), bw);

    GtkWidget *tb_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6);
    gtk_container_add(GTK_CONTAINER(evbox), tb_box);

    bw->title_lbl = gtk_label_new(title);
    gtk_box_pack_start(GTK_BOX(tb_box), bw->title_lbl, TRUE, TRUE, 8);

    GtkWidget *btn_min = gtk_button_new_with_label("—");
    GtkWidget *btn_max = gtk_button_new_with_label("❐");
    GtkWidget *btn_cls = gtk_button_new_with_label("✕");
    gtk_button_set_relief(GTK_BUTTON(btn_min), GTK_RELIEF_NONE);
    gtk_button_set_relief(GTK_BUTTON(btn_max), GTK_RELIEF_NONE);
    gtk_button_set_relief(GTK_BUTTON(btn_cls), GTK_RELIEF_NONE);
    g_signal_connect(btn_min, "clicked", G_CALLBACK(on_win_min), bw);
    g_signal_connect(btn_max, "clicked", G_CALLBACK(on_win_max), bw);
    g_signal_connect(btn_cls, "clicked", G_CALLBACK(on_win_close), bw);
    gtk_box_pack_end(GTK_BOX(tb_box), btn_cls, FALSE, FALSE, 4);
    gtk_box_pack_end(GTK_BOX(tb_box), btn_max, FALSE, FALSE, 2);
    gtk_box_pack_end(GTK_BOX(tb_box), btn_min, FALSE, FALSE, 2);
    gtk_box_pack_start(GTK_BOX(vbox), evbox, FALSE, FALSE, 0);

    /* Address & Nav Bar */
    GtkWidget *nav = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6);
    gtk_container_set_border_width(GTK_CONTAINER(nav), 6);
    GtkWidget *b_back = gtk_button_new_with_label("←");
    GtkWidget *b_fwd  = gtk_button_new_with_label("→");
    GtkWidget *b_rel  = gtk_button_new_with_label("⟳");
    GtkWidget *b_fast = gtk_button_new_with_label("Fast.com");
    GtkWidget *b_yt   = gtk_button_new_with_label("YouTube");
    GtkWidget *b_tab  = gtk_button_new_with_label("+ Tab");
    bw->url_entry = gtk_entry_new();
    gtk_entry_set_text(GTK_ENTRY(bw->url_entry), url);
    bw->status_lbl = gtk_label_new("Ready");

    g_signal_connect(b_back, "clicked", G_CALLBACK(on_back), bw);
    g_signal_connect(b_fwd,  "clicked", G_CALLBACK(on_fwd), bw);
    g_signal_connect(b_rel,  "clicked", G_CALLBACK(on_reload), bw);
    g_signal_connect(b_fast, "clicked", G_CALLBACK(on_fast_btn), bw);
    g_signal_connect(b_yt,   "clicked", G_CALLBACK(on_yt_btn), bw);
    g_signal_connect(b_tab,  "clicked", G_CALLBACK(on_new_tab), bw);
    g_signal_connect(bw->url_entry, "activate", G_CALLBACK(on_url_activate), bw);

    gtk_box_pack_start(GTK_BOX(nav), b_back, FALSE, FALSE, 2);
    gtk_box_pack_start(GTK_BOX(nav), b_fwd, FALSE, FALSE, 2);
    gtk_box_pack_start(GTK_BOX(nav), b_rel, FALSE, FALSE, 2);
    gtk_box_pack_start(GTK_BOX(nav), bw->url_entry, TRUE, TRUE, 4);
    gtk_box_pack_start(GTK_BOX(nav), b_fast, FALSE, FALSE, 2);
    gtk_box_pack_start(GTK_BOX(nav), b_yt, FALSE, FALSE, 2);
    gtk_box_pack_start(GTK_BOX(nav), b_tab, FALSE, FALSE, 2);
    gtk_box_pack_start(GTK_BOX(nav), bw->status_lbl, FALSE, FALSE, 6);
    gtk_box_pack_start(GTK_BOX(vbox), nav, FALSE, FALSE, 0);

    bw->notebook = gtk_notebook_new();
    gtk_box_pack_start(GTK_BOX(vbox), bw->notebook, TRUE, TRUE, 0);
    add_browser_tab(bw, url);

    gtk_widget_show_all(bw->win);
    gtk_window_present(GTK_WINDOW(bw->win));
}

static void on_js_msg(WebKitUserContentManager *mgr, WebKitJavascriptResult *res, gpointer data) {
    JSCValue *val = webkit_javascript_result_get_js_value(res);
    if (!jsc_value_is_object(val)) return;
    JSCValue *act_v = jsc_value_object_get_property(val, "action");
    gchar *act = jsc_value_to_string(act_v);
    g_object_unref(act_v);

    if (g_strcmp0(act, "open_browser") == 0) {
        JSCValue *u_v = jsc_value_object_get_property(val, "url");
        JSCValue *t_v = jsc_value_object_get_property(val, "title");
        JSCValue *th_v = jsc_value_object_get_property(val, "theme");
        gchar *u = jsc_value_to_string(u_v);
        gchar *t = jsc_value_to_string(t_v);
        gchar *th = jsc_value_to_string(th_v);
        open_nova_browser(t ? t : "Chrome", u ? u : "https://www.google.com", g_strcmp0(th, "dark") == 0);
        g_free(u); g_free(t); g_free(th);
        g_object_unref(u_v); g_object_unref(t_v); g_object_unref(th_v);
    } else if (g_strcmp0(act, "poweroff") == 0) {
        system("poweroff -f || halt -p");
    } else if (g_strcmp0(act, "reboot") == 0) {
        system("reboot -f");
    }
    g_free(act);
}

static void on_main_load_changed(WebKitWebView *wv, WebKitLoadEvent ev, gpointer data) {
    g_printerr("[WEBKIT] load event: %d uri=%s\n", (int)ev, webkit_web_view_get_uri(wv));
}

int main(int argc, char *argv[]) {
    gtk_init(&argc, &argv);

    WebKitWebContext *ctx = webkit_web_context_get_default();
    webkit_web_context_set_cache_model(ctx, WEBKIT_CACHE_MODEL_WEB_BROWSER);
    webkit_web_context_set_process_model(ctx, WEBKIT_PROCESS_MODEL_SHARED_SECONDARY_PROCESS);
    webkit_web_context_set_tls_errors_policy(ctx, WEBKIT_TLS_ERRORS_POLICY_IGNORE);
    g_signal_connect(ctx, "download-started", G_CALLBACK(on_download_started), NULL);

    GtkCssProvider *css = gtk_css_provider_new();
    gtk_css_provider_load_from_data(css,
        "#nova-tb-light { background: #5CB3FF; color: #000000; font-weight: bold; }"
        "#nova-tb-dark  { background: #16447D; color: #FFFFFF; font-weight: bold; }",
        -1, NULL);
    gtk_style_context_add_provider_for_screen(
        gdk_screen_get_default(), GTK_STYLE_PROVIDER(css), GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);

    g_main_win = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_decorated(GTK_WINDOW(g_main_win), FALSE);
    gtk_window_set_default_size(GTK_WINDOW(g_main_win), 1920, 1080);
    gtk_window_move(GTK_WINDOW(g_main_win), 0, 0);
    g_signal_connect(g_main_win, "destroy", G_CALLBACK(gtk_main_quit), NULL);

    WebKitUserContentManager *ucm = webkit_user_content_manager_new();
    webkit_user_content_manager_register_script_message_handler(ucm, "novaos");
    g_signal_connect(ucm, "script-message-received::novaos", G_CALLBACK(on_js_msg), NULL);

    WebKitWebView *wv = WEBKIT_WEB_VIEW(webkit_web_view_new_with_user_content_manager(ucm));
    configure_webview_settings(wv);
    g_signal_connect(wv, "load-changed", G_CALLBACK(on_main_load_changed), NULL);

    gtk_container_add(GTK_CONTAINER(g_main_win), GTK_WIDGET(wv));
    const gchar *target_url = (argc > 1) ? argv[1] : "http://127.0.0.1:8090/";
    webkit_web_view_load_uri(wv, target_url);

    gtk_widget_show_all(g_main_win);
    gtk_widget_grab_focus(GTK_WIDGET(wv));
    gtk_main();
    return 0;
}
