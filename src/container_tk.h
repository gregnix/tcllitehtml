#ifndef CONTAINER_TK_H
#define CONTAINER_TK_H

/* litehtml ZUERST — vor Tk (False/True Makro-Konflikt) */
#include <litehtml.h>
#ifdef False
#  undef False
#endif
#ifdef True
#  undef True
#endif
#ifdef None
#  undef None
#endif
#include <tcl.h>
#include <tk.h>
#include <string>
#include <map>
#include <vector>

class ContainerTk : public litehtml::document_container
{
public:
    ContainerTk(Tcl_Interp *interp, const std::string& canvas_path,
                const std::string &default_font, int default_font_size);
    virtual ~ContainerTk();

    void begin_draw(int w, int h, int scroll_y, const std::string &bg);
    void end_draw();
    void set_on_link_click(const std::string& s) { _on_link_click = s; }
    void clear_width_cache() { _width_cache.clear(); }
    void set_image(const std::string& url, const std::string& photo);

    /* --- Selection --- */
    struct TextItem {
        int x, y, w, h;          /* Screen-Koordinaten */
        int doc_y;                /* Dokument-Y (= y + scroll_y beim Zeichnen) */
        std::string text;
        std::string font;
    };
    const std::vector<TextItem>& text_log() const { return _text_log; }
    void clear_text_log() { _text_log.clear(); }
    std::string get_text_in_rect(int x1, int y1, int x2, int y2) const;

    /* --- Font --- */
    virtual litehtml::uint_ptr create_font(const litehtml::font_description&,
        const litehtml::document*, litehtml::font_metrics*) override;
    virtual void delete_font(litehtml::uint_ptr) override;
    virtual litehtml::pixel_t text_width(const char*, litehtml::uint_ptr) override;
    virtual void draw_text(litehtml::uint_ptr, const char*, litehtml::uint_ptr,
        litehtml::web_color, const litehtml::position&) override;

    /* --- Metrics --- */
    virtual litehtml::pixel_t pt_to_px(float pt) const override
        { return (litehtml::pixel_t)(pt * 96.0f / 72.0f); }
    virtual litehtml::pixel_t get_default_font_size() const override
        { return (litehtml::pixel_t)_default_font_size; }
    virtual const char* get_default_font_name() const override
        { return _default_font.c_str(); }

    /* --- Backgrounds --- */
    virtual void draw_solid_fill(litehtml::uint_ptr,
        const litehtml::background_layer&, const litehtml::web_color&) override;
    virtual void draw_linear_gradient(litehtml::uint_ptr,
        const litehtml::background_layer&,
        const litehtml::background_layer::linear_gradient&) override;
    virtual void draw_radial_gradient(litehtml::uint_ptr,
        const litehtml::background_layer&,
        const litehtml::background_layer::radial_gradient&) override;
    virtual void draw_conic_gradient(litehtml::uint_ptr,
        const litehtml::background_layer&,
        const litehtml::background_layer::conic_gradient&) override;

    /* --- Borders / Lists --- */
    virtual void draw_borders(litehtml::uint_ptr, const litehtml::borders&,
        const litehtml::position&, bool) override;
    virtual void draw_list_marker(litehtml::uint_ptr,
        const litehtml::list_marker&) override;

    /* --- Images --- */
    virtual void load_image(const char*, const char*, bool) override;
    virtual void get_image_size(const char*, const char*,
        litehtml::size&) override;
    virtual void draw_image(litehtml::uint_ptr,
        const litehtml::background_layer&,
        const std::string&, const std::string&) override;

    /* --- Stubs --- */
    virtual void set_caption(const char*) override {}
    virtual void set_base_url(const char* url) override {
        /* Nur setzen wenn keine externe URL gesetzt wurde */
        if (url && _base_url.empty()) _base_url = url;
    }
    void set_external_base_url(const char* url) {
        if (url) _base_url = url;
    }
    void reset_base_url() { _base_url = ""; }
    const std::string& base_url() const { return _base_url; }
    virtual void link(const std::shared_ptr<litehtml::document>&,
        const litehtml::element::ptr&) override {}
    virtual void on_anchor_click(const char*, const litehtml::element::ptr&) override;
    virtual void on_mouse_event(const litehtml::element::ptr&,
        litehtml::mouse_event) override {}
    virtual void set_cursor(const char* cursor) override;
    virtual void transform_text(litehtml::string&, litehtml::text_transform) override;
    virtual void import_css(litehtml::string&,
        const litehtml::string&, litehtml::string&) override;
    virtual void set_clip(const litehtml::position&,
        const litehtml::border_radiuses&) override {}
    virtual void del_clip() override {}
    virtual litehtml::element::ptr create_element(const char*,
        const litehtml::string_map&,
        const litehtml::document::ptr&) override { return nullptr; }
    virtual void get_media_features(litehtml::media_features&) const override;
    virtual void get_language(litehtml::string&, litehtml::string&) const override;
    virtual litehtml::string resolve_color(
        const litehtml::string&) const override;
    virtual void get_viewport(litehtml::position&) const override;

private:
    Tcl_Interp  *_interp;
    std::string  _canvas;
    std::string  _default_font;
    int          _default_font_size;
    int          _scroll_y = 0, _width = 800, _height = 600;
    std::string  _on_link_click;   /* Link-Callback Tcl-Script */

    struct FontInfo { std::string tk_font; int size; bool bold, italic; };
    std::map<litehtml::uint_ptr, FontInfo> _fonts;
    litehtml::uint_ptr _next_font_id = 1;
    std::map<std::string, std::string> _images;

    /* text_width Cache */
    struct WidthKey {
        std::string text;
        litehtml::uint_ptr font_id;
        bool operator<(const WidthKey& o) const {
            if (font_id != o.font_id) return font_id < o.font_id;
            return text < o.text;
        }
    };
    std::map<WidthKey, litehtml::pixel_t> _width_cache;
    std::vector<TextItem> _text_log;  /* für Selection */
    std::string _base_url;             /* für import_css — public für direkten Reset */
    std::map<std::string,std::string> _css_cache; /* URL → CSS-Text */

    std::string color_to_tk(const litehtml::web_color&);
    void canvas_eval(const std::string&);
    void draw_rect_fill(const litehtml::position&, const litehtml::web_color&);
};
#endif
