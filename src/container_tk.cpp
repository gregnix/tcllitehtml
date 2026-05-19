/* container_tk.cpp -- Tk-Canvas backend for litehtml
 *
 * Copyright (c) 2026 Gregor Ebbing
 * BSD 2-Clause License
 */

#include "container_tk.h"
#include <cstdio>
#include <cstring>
#include <cctype>

/* ================================================================== */
ContainerTk::ContainerTk(Tcl_Interp *interp, const std::string &canvas_path,
                          const std::string &default_font,
                          int default_font_size)
    : _interp(interp),
      _default_font(default_font),
      _default_font_size(default_font_size)
{
    /* Canvas-Pfad = Widget-Pfad + ".c" */
    _canvas = canvas_path;

    /* Canvas wurde bereits von Tcl-Seite erstellt */
}

ContainerTk::~ContainerTk() {}

/* ================================================================== */
void ContainerTk::begin_draw(int width, int height,
                              int scroll_y, const std::string &bg)
{
    /* Stufe 2: width-Änderung invalidiert text-Cache; Höhe ist jetzt
     * doc-Höhe, nicht Viewport — bei Höhen-Änderung allein nicht
     * neu messen. */
    if (width != _width) _width_cache.clear();
    _width = width; _height = height; _scroll_y = scroll_y;
    canvas_eval(_canvas + " delete all");
    _text_log.clear();
    /* Hintergrund — als ein Rect mit Tag _bg, damit do_draw es
     * nachträglich auf doc_height vergrößern kann */
    std::string fill = bg.empty() ? "white" : bg;
    canvas_eval(_canvas + " create rectangle 0 0 " +
        std::to_string(width) + " " + std::to_string(height) +
        " -fill " + fill + " -outline {} -tags _bg");
}

void ContainerTk::end_draw() {
    /* Kein update idletasks — kann auf Windows Events auslösen
     * während litehtml noch rendert → Crash */
}

/* ================================================================== */
std::string ContainerTk::color_to_tk(const litehtml::web_color &c)
{
    if (c.alpha < 10) return "";  /* transparent */
    char buf[16];
    snprintf(buf, sizeof(buf), "#%02x%02x%02x",
             (int)c.red, (int)c.green, (int)c.blue);
    return std::string(buf);
}

void ContainerTk::canvas_eval(const std::string &script)
{
    if (!_interp) return;
    int rc = Tcl_Eval(_interp, script.c_str());
    if (rc != TCL_OK) {
        /* Fehler still ignorieren */
    }
}

/* ================================================================== */
/* Fonts                                                              */
/* ================================================================== */

litehtml::uint_ptr ContainerTk::create_font(
    const litehtml::font_description& descr,
    const litehtml::document* /*doc*/,
    litehtml::font_metrics* fm)
{
    FontInfo fi;
    fi.size   = (descr.size > 0) ? (int)descr.size : _default_font_size;
    fi.bold   = (descr.weight >= 700);
    fi.italic = false;

    /* Familie: erste aus der kommagetrennte Liste */
    std::string family = descr.family.empty() ?
        _default_font : std::string(descr.family);
    {
        size_t comma = family.find(',');
        if (comma != std::string::npos) family = family.substr(0, comma);
        /* Whitespace + Anführungszeichen trimmen */
        auto trim = [](std::string s) {
            size_t a = s.find_first_not_of(" \t\"'");
            size_t b = s.find_last_not_of(" \t\"'");
            return (a == std::string::npos) ? "" : s.substr(a, b-a+1);
        };
        family = trim(family);
        if (family.empty()) family = _default_font;
    }

    fi.tk_font = "{" + family + "} " + std::to_string(fi.size);
    if (fi.bold)   fi.tk_font += " bold";
    if (fi.italic) fi.tk_font += " italic";

    /* Font-Existenz prüfen — auf Windows gibt es kein "Sans" */
    {
        std::string check = "catch {font metrics {" + fi.tk_font + "} -ascent}";
        if (Tcl_Eval(_interp, check.c_str()) != TCL_OK ||
            atoi(Tcl_GetStringResult(_interp)) != 0) {
            /* Font nicht gefunden — Fallback */
            #ifdef _WIN32
                fi.tk_font = "{Arial} " + std::to_string(fi.size);
            #else
                fi.tk_font = "{DejaVu Sans} " + std::to_string(fi.size);
            #endif
            if (fi.bold)   fi.tk_font += " bold";
            if (fi.italic) fi.tk_font += " italic";
        }
    }

    /* Metriken */
    if (fm) {
        std::string s = "font metrics {" + fi.tk_font + "} -ascent";
        fm->ascent = (Tcl_Eval(_interp, s.c_str()) == TCL_OK) ?
            atoi(Tcl_GetStringResult(_interp)) : fi.size * 3 / 4;
        s = "font metrics {" + fi.tk_font + "} -descent";
        fm->descent = (Tcl_Eval(_interp, s.c_str()) == TCL_OK) ?
            atoi(Tcl_GetStringResult(_interp)) : fi.size / 4;
        fm->height   = fm->ascent + fm->descent;
        fm->x_height = fm->ascent / 2;
        fm->draw_spaces = false;
    }

    litehtml::uint_ptr id = _next_font_id++;
    _fonts[id] = fi;
    return id;
}

void ContainerTk::delete_font(litehtml::uint_ptr hFont)
{
    _fonts.erase(hFont);
}

litehtml::pixel_t ContainerTk::text_width(
    const char *text, litehtml::uint_ptr hFont)
{
    if (!text || !text[0]) return 0;
    if (!_interp) return 8;
    auto fit = _fonts.find(hFont);
    if (fit == _fonts.end())
        return (litehtml::pixel_t)(strlen(text) * 8);

    /* Cache-Lookup */
    WidthKey key{std::string(text), hFont};
    auto cit = _width_cache.find(key);
    if (cit != _width_cache.end()) return cit->second;

    litehtml::pixel_t w = 0;

    /* Tk_TextWidth: direkter C-Aufruf — kein Tcl_Eval-Overhead
     * Kein Fallback: wenn Tk_TextWidth 0 liefert für nichtleeren Text
     * → Fehler ausgeben (falsches Layout wäre schlimmer als Fehlermeldung) */
    Tk_Window tkwin = Tk_NameToWindow(_interp, _canvas.c_str(),
                                       Tk_MainWindow(_interp));
    if (tkwin) {
        Tk_Font tkfont = Tk_GetFont(_interp, tkwin,
                                     fit->second.tk_font.c_str());
        if (tkfont) {
            w = (litehtml::pixel_t)Tk_TextWidth(tkfont, text,
                                                  (int)strlen(text));
            Tk_FreeFont(tkfont);
        } else {
            fprintf(stderr, "tcllitehtml: Tk_GetFont fehlgeschlagen: %s\n",
                fit->second.tk_font.c_str());
        }
    } else {
        fprintf(stderr, "tcllitehtml: Tk_NameToWindow fehlgeschlagen: %s\n",
            _canvas.c_str());
    }

    /* Letzter Ausweg: Schätzung */
    if (w == 0)
        w = (litehtml::pixel_t)(strlen(text) * fit->second.size / 2);

    _width_cache[key] = w;
    return w;
}

void ContainerTk::draw_text(
    litehtml::uint_ptr /*hdc*/,
    const char *text,
    litehtml::uint_ptr hFont,
    litehtml::web_color color,
    const litehtml::position &pos)
{
    if (!text || !text[0]) return;
    int y = pos.y;  /* doc-Koordinate (Stufe 2: kein y-Offset mehr) */
    /* Kein Clip-Check — Tk's Canvas clippt selbst beim Rendern,
     * und yview macht das Scrolling */

    if (!_interp) return;
    auto it = _fonts.find(hFont);
    std::string font = (it != _fonts.end()) ?
        it->second.tk_font :
        _default_font + " " + std::to_string(_default_font_size);

    std::string fill = color_to_tk(color);
    if (fill.empty()) fill = "#000000";

/* Text via Tcl-Variable übergeben — kein Escaping nötig */
    Tcl_SetVar(_interp, "::tcllitehtml::_t", text, TCL_GLOBAL_ONLY);
    canvas_eval(_canvas + " create text " +
        std::to_string(pos.x) + " " + std::to_string(y) +
        " -text $::tcllitehtml::_t" +
        " -font {" + font + "}" +
        " -fill " + fill + " -anchor nw");

    /* Text für Selection loggen */
    TextItem ti;
    ti.x     = pos.x;
    ti.y     = y;
    ti.doc_y = pos.y;
    ti.h     = pos.height > 0 ? pos.height : it->second.size;
    ti.text  = std::string(text);
    ti.font  = font;
    /* Breite aus Cache oder messen */
    WidthKey wk{ti.text, hFont};
    auto wci = _width_cache.find(wk);
    ti.w = (wci != _width_cache.end()) ? (int)wci->second : (int)(ti.text.size() * 8);
    _text_log.push_back(ti);
}

/* ================================================================== */
/* Backgrounds                                                        */
/* ================================================================== */

void ContainerTk::draw_rect_fill(
    const litehtml::position &pos, const litehtml::web_color &color)
{
    std::string fill = color_to_tk(color);
    if (fill.empty()) return;
    int y = pos.y;  /* doc-Koordinate (Stufe 2) */
    canvas_eval(_canvas + " create rectangle " +
        std::to_string(pos.x) + " " + std::to_string(y) + " " +
        std::to_string(pos.x + pos.width) + " " +
        std::to_string(y + pos.height) +
        " -fill " + fill + " -outline {}");
}

void ContainerTk::draw_solid_fill(
    litehtml::uint_ptr /*hdc*/,
    const litehtml::background_layer &layer,
    const litehtml::web_color &color)
{
if (color == litehtml::web_color::transparent) return;
    if (color.alpha < 10) return;
    draw_rect_fill(layer.clip_box, color);
}

void ContainerTk::draw_linear_gradient(
    litehtml::uint_ptr /*hdc*/,
    const litehtml::background_layer &layer,
    const litehtml::background_layer::linear_gradient &g)
{
    /* Phase 1: Ersten Stop als Vollfarbe */
    if (!g.color_points.empty())
        draw_rect_fill(layer.clip_box, g.color_points[0].color);
}

void ContainerTk::draw_radial_gradient(
    litehtml::uint_ptr /*hdc*/,
    const litehtml::background_layer &layer,
    const litehtml::background_layer::radial_gradient &g)
{
    if (!g.color_points.empty())
        draw_rect_fill(layer.clip_box, g.color_points[0].color);
}

void ContainerTk::draw_conic_gradient(
    litehtml::uint_ptr /*hdc*/,
    const litehtml::background_layer &layer,
    const litehtml::background_layer::conic_gradient &g)
{
    if (!g.color_points.empty())
        draw_rect_fill(layer.clip_box, g.color_points[0].color);
}

/* ================================================================== */
/* Borders                                                            */
/* ================================================================== */

void ContainerTk::draw_borders(
    litehtml::uint_ptr /*hdc*/,
    const litehtml::borders &b,
    const litehtml::position &pos,
    bool /*root*/)
{
    int x1 = pos.x, y1 = pos.y;
    int x2 = x1 + pos.width, y2 = y1 + pos.height;
    if (y2 < 0 || y1 > _height) return;

    auto draw_line = [&](int ax, int ay, int bx, int by,
                          const litehtml::border &border) {
        if (border.width <= 0) return;
        std::string fill = color_to_tk(border.color);
        if (fill.empty()) return;
        canvas_eval(_canvas + " create line " +
            std::to_string(ax) + " " + std::to_string(ay) + " " +
            std::to_string(bx) + " " + std::to_string(by) +
            " -fill " + fill +
            " -width " + std::to_string((int)border.width));
    };

    draw_line(x1, y1, x2, y1, b.top);
    draw_line(x1, y2, x2, y2, b.bottom);
    draw_line(x1, y1, x1, y2, b.left);
    draw_line(x2, y1, x2, y2, b.right);
}

void ContainerTk::draw_list_marker(
    litehtml::uint_ptr /*hdc*/,
    const litehtml::list_marker &marker)
{
    int y = marker.pos.y;
    /* Stufe 2: kein Clip — doc-Koordinaten, Tk's Canvas clippt */
    canvas_eval(_canvas + " create oval " +
        std::to_string(marker.pos.x) + " " + std::to_string(y) + " " +
        std::to_string(marker.pos.x + 5) + " " + std::to_string(y + 5) +
        " -fill #333333 -outline {}");
}

/* ================================================================== */
/* Images                                                             */
/* ================================================================== */

/* Löst eine URL gegen baseurl auf */
static std::string resolve_url(const std::string &url,
                                const std::string &baseurl)
{
    if (url.empty()) return url;
    /* Bereits absolut (http://, /, ~, ...) */
    if (url[0] == '/' || url[0] == '~') return url;
    if (url.size() > 4 && url.substr(0,4) == "http") return url;
    if (url.size() > 4 && url.substr(0,4) == "file") return url;
    /* Relativ + baseurl vorhanden */
    if (!baseurl.empty()) {
        /* Verzeichnis aus baseurl extrahieren */
        size_t slash = baseurl.rfind('/');
        if (slash == std::string::npos) slash = baseurl.rfind('\\');
        if (slash != std::string::npos)
            return baseurl.substr(0, slash + 1) + url;
    }
    return url;
}

void ContainerTk::load_image(const char *src, const char *baseurl,
                               bool /*redraw*/)
{
    if (!src || !src[0]) return;
    std::string url = std::string(src);
    std::string resolved = resolve_url(url, baseurl ? baseurl : "");

    /* Schon geladen? */
    if (_images.count(url)) return;

    /* Eindeutiger Tk-Foto-Name */
    std::string name = "tcllitehtml_img_" + std::to_string(_images.size());
    _images[url] = name;

    /* Bild laden — versuche resolved, dann original */
    std::string cmd =
        "if {[catch {image create photo " + name +
        " -file {" + resolved + "}} _err]} {"
        "  if {[catch {image create photo " + name +
        " -file {" + url + "}} _err2]} {"
        "    image create photo " + name +
        "  }"  /* leeres Bild als Platzhalter */
        "}";
    Tcl_Eval(_interp, cmd.c_str());
}

void ContainerTk::get_image_size(const char *src, const char *baseurl,
                                   litehtml::size &sz)
{
    sz.width = sz.height = 0;
    if (!src) return;
    std::string url = std::string(src);
    /* Falls noch nicht geladen, laden */
    if (!_images.count(url))
        load_image(src, baseurl, false);
    auto it = _images.find(url);
    if (it == _images.end()) return;
    /* Tk-Standard: image width $name / image height $name */
    std::string cmd = "image width " + it->second;
    if (Tcl_Eval(_interp, cmd.c_str()) == TCL_OK)
        sz.width = atoi(Tcl_GetStringResult(_interp));
    cmd = "image height " + it->second;
    if (Tcl_Eval(_interp, cmd.c_str()) == TCL_OK)
        sz.height = atoi(Tcl_GetStringResult(_interp));
}

void ContainerTk::set_image(const std::string &url,
                             const std::string &photo_name)
{
    /* Externes Bild setzen (via tcllitehtml::_setimage PATH URL PHOTO) */
    if (_images.count(url)) {
        /* Bestehendes leeres Bild mit Daten füllen */
        std::string cmd = _images[url] + " copy " + photo_name;
        Tcl_Eval(_interp, cmd.c_str());
    } else {
        _images[url] = photo_name;
    }
}

void ContainerTk::draw_image(
    litehtml::uint_ptr /*hdc*/,
    const litehtml::background_layer &layer,
    const std::string &url,
    const std::string & /*base_url*/)
{
    auto it = _images.find(url);
    if (it == _images.end()) return;
    int x = layer.border_box.x;
    int y = layer.border_box.y;
    int w = layer.border_box.width;
    int h = layer.border_box.height;

    /* Bild skaliert zeichnen wenn Größe bekannt */
    std::string cmd;
    if (w > 0 && h > 0) {
        /* Bild auf Zielgröße w×h skalieren via photo copy -to */
        cmd = "catch {"
            "set _iw [image width " + it->second + "];"
            "set _ih [image height " + it->second + "];"
            "if {$_iw > 0 && $_ih > 0} {"
            "  set _sc [image create photo];"
            "  $_sc copy " + it->second + " -to 0 0 " + std::to_string(w) + " " + std::to_string(h) + ";"
            "  " + _canvas + " create image " +
                std::to_string(x) + " " + std::to_string(y) +
            "  -image $_sc -anchor nw;"
            "} else {"
            "  " + _canvas + " create image " +
                std::to_string(x) + " " + std::to_string(y) +
            "  -image " + it->second + " -anchor nw;"
            "}"
            "}";
    } else {
        cmd = _canvas + " create image " +
            std::to_string(x) + " " + std::to_string(y) +
            " -image " + it->second + " -anchor nw";
    }
    canvas_eval(cmd);
}

std::string ContainerTk::get_text_in_rect(int x1, int y1,
                                            int x2, int y2) const
{
    /* Sammle alle TextItems deren Mittelpunkt im Rechteck liegt.
     * Sortiert nach doc_y, dann x → natürliche Lesereihenfolge. */
    std::vector<const TextItem*> hits;
    for (const auto& ti : _text_log) {
        int cx = ti.x + ti.w / 2;
        int cy = ti.y + ti.h / 2;
        if (cx >= x1 && cx <= x2 && cy >= y1 && cy <= y2)
            hits.push_back(&ti);
    }
    if (hits.empty()) return "";

    /* Sortieren: erst doc_y, dann x */
    std::sort(hits.begin(), hits.end(),
        [](const TextItem *a, const TextItem *b) {
            if (a->doc_y != b->doc_y) return a->doc_y < b->doc_y;
            return a->x < b->x;
        });

    /* Text zusammensetzen: neue Zeile wenn doc_y weit springt */
    std::string result;
    int prev_y = -999, prev_x = -999;
    for (const auto *ti : hits) {
        if (prev_y >= 0 && ti->doc_y > prev_y + ti->h / 2)
            result += "\n";
        else if (prev_x >= 0 && ti->x > prev_x + 4)
            result += " ";
        result += ti->text;
        prev_y = ti->doc_y;
        prev_x = ti->x + ti->w;
    }
    return result;
}

/* ================================================================== */
/* Misc                                                               */
/* ================================================================== */

void ContainerTk::set_cursor(const char *cursor)
{
    if (!cursor || !_interp) return;
    std::string tk_cursor;
    std::string c(cursor);
    /* CSS cursor → Tk cursor */
    if (c == "pointer" || c == "hand")     tk_cursor = "hand2";
    else if (c == "text" || c == "beam")   tk_cursor = "xterm";
    else if (c == "wait" || c == "busy")   tk_cursor = "watch";
    else if (c == "crosshair")             tk_cursor = "crosshair";
    else if (c == "not-allowed")           tk_cursor = "circle";
    else if (c == "move")                  tk_cursor = "fleur";
    else if (c == "default" || c == "auto") tk_cursor = "";
    else                                   tk_cursor = "";
    std::string cmd = _canvas + " configure -cursor {" + tk_cursor + "}";
    Tcl_Eval(_interp, cmd.c_str());
}

void ContainerTk::on_anchor_click(const char *url,
    const litehtml::element::ptr &)
{
    if (_on_link_click.empty() || !url) return;
    /* "after idle {cmd url}" — Callback NACH Ende des Click-Events ausführen.
     * Sonst: Callback lädt neues HTML → Dokument wird zerstört →
     * litehtml greift danach noch auf altes Dokument zu → SIGSEGV */
    std::string safe_url(url);
    /* Geschweifte Klammern in URL escapen */
    std::string escaped_url;
    for (char c : safe_url) {
        if (c == '{' || c == '}' || c == '\\') escaped_url += '\\';
        escaped_url += c;
    }
    std::string after_cmd = "after idle [list " + _on_link_click +
        " {" + escaped_url + "}]";
    Tcl_Eval(_interp, after_cmd.c_str());
}

void ContainerTk::transform_text(litehtml::string &text,
    litehtml::text_transform tt)
{
    if (tt == litehtml::text_transform_uppercase)
        for (auto &c : text) c = (char)toupper((unsigned char)c);
    else if (tt == litehtml::text_transform_lowercase)
        for (auto &c : text) c = (char)tolower((unsigned char)c);
}

void ContainerTk::import_css(litehtml::string &text,
    const litehtml::string &url, litehtml::string &baseurl)
{
    if (url.empty()) return;

    /* URL gegen baseurl auflösen — eigene _base_url wenn Parameter leer */
    std::string effective_base = baseurl.empty() ? _base_url : baseurl;
    std::string full_url = url;
    if (url.substr(0, 4) != "http" && !effective_base.empty()) {
        if (url[0] == '/') {
            /* Absoluter Pfad: Origin aus baseurl */
            size_t p = effective_base.find("://");
            if (p != std::string::npos) {
                size_t slash = effective_base.find('/', p + 3);
                if (slash != std::string::npos)
                    full_url = effective_base.substr(0, slash) + url;
                else
                    full_url = effective_base + url;
            }
        } else {
            /* Relativ: Verzeichnis aus baseurl */
            size_t slash = effective_base.rfind('/');
            if (slash != std::string::npos)
                full_url = effective_base.substr(0, slash + 1) + url;
        }
    }
    fprintf(stderr, "import_css: %s → %s\n", url.c_str(), full_url.c_str());

    /* HTTP/HTTPS: via Tcl http::geturl laden */
    if (full_url.substr(0, 4) == "http") {
        std::string cmd =
            "catch {"
            "  package require http;"
            "  set _tok [http::geturl {" + full_url + "} -timeout 8000];"
            "  set ::tcllitehtml::_css [http::data $_tok];"
            "  http::cleanup $_tok"
            "}";
        if (Tcl_Eval(_interp, cmd.c_str()) == TCL_OK) {
            const char *css = Tcl_GetVar(_interp,
                "::tcllitehtml::_css", TCL_GLOBAL_ONLY);
            if (css) text = css;
        }
        return;
    }

    /* Lokale Datei */
    Tcl_Channel ch = Tcl_OpenFileChannel(_interp, full_url.c_str(), "r", 0);
    if (!ch) return;
    char buf[4096]; int n;
    while ((n = Tcl_Read(ch, buf, (int)sizeof(buf)-1)) > 0) {
        buf[n] = '\0'; text += buf;
    }
    Tcl_Close(_interp, ch);
}

void ContainerTk::get_media_features(litehtml::media_features &mf) const
{
    mf.type          = litehtml::media_type_screen;
    mf.width         = _width;
    mf.height        = _height;
    mf.device_width  = _width;
    mf.device_height = _height;
    mf.color         = 8;
    mf.resolution    = 96;
}

void ContainerTk::get_language(litehtml::string &lang,
    litehtml::string &cult) const
{ lang = "de"; cult = ""; }

void ContainerTk::get_viewport(litehtml::position &vp) const
{ vp.x = 0; vp.y = 0; vp.width = _width; vp.height = _height; }

/* ================================================================== */
/* resolve_color: benannte CSS-Farben → #RRGGBB                      */
/* Verhindert den litehtml parse_name_color Rekursions-Bug           */
/* ================================================================== */

litehtml::string ContainerTk::resolve_color(
    const litehtml::string &color) const
{
    /* Wenn schon #RRGGBB oder rgb(...) → direkt zurück (kein Debug-Spam) */
    if (!color.empty() && color[0] == '#') return color;
    if (color.size() >= 3 && color.substr(0,3) == "rgb") return color;


    /* Tabelle der häufigsten CSS-Farbnamen */
    static const struct { const char *name; const char *hex; } table[] = {
        {"white",      "#ffffff"}, {"black",      "#000000"},
        {"red",        "#ff0000"}, {"green",      "#008000"},
        {"blue",       "#0000ff"}, {"yellow",     "#ffff00"},
        {"orange",     "#ffa500"}, {"purple",     "#800080"},
        {"gray",       "#808080"}, {"grey",       "#808080"},
        {"silver",     "#c0c0c0"}, {"navy",       "#000080"},
        {"teal",       "#008080"}, {"aqua",       "#00ffff"},
        {"cyan",       "#00ffff"}, {"magenta",    "#ff00ff"},
        {"fuchsia",    "#ff00ff"}, {"maroon",     "#800000"},
        {"olive",      "#808000"}, {"lime",       "#00ff00"},
        {"transparent","#00000000"},
        {nullptr, nullptr}
    };

    /* Case-insensitive Suche */
    std::string low = color;
    for (auto &c : low) c = (char)tolower((unsigned char)c);

    for (int i = 0; table[i].name; i++) {
        if (low == table[i].name)
            return table[i].hex;
    }

    /* CSS-Keywords die keine Farbnamen sind (underline, initial, inherit etc.)
     * → "transparent" zurückgeben.
     *
     * NICHT den original String zurückgeben → Endlosrekursion:
     *   resolve_color("underline") → return "underline"
     *   → litehtml parst "underline" erneut als Farbe
     *   → resolve_color("underline") → ...
     *
     * NICHT "" zurückgeben → litehtml crasht intern mit leerem String.
     *
     * "transparent" ist gültig, stoppt die Rekursion, macht keinen Schaden.
     */
    return "transparent";
}

/* ================================================================== */
/* Debug-Ausgabe für create_font und text_width                      */
/* Stille Fehler sichtbar machen — Prinzip wie in TkMoin             */
/* ================================================================== */
/* Hinweis: canvas_eval gibt bereits Fehler aus.
   Weitere Debug-Ausgaben mit -DDEBUG_TCLLITEHTML aktivierbar:

   make CBASE_EXTRA="-DDEBUG_TCLLITEHTML"

   Dann wird jeder font-create und jeder canvas-Befehl geloggt.
*/
