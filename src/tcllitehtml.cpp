/* tcllitehtml.cpp -- tcllitehtml backend (C++ Seite)
 *
 * Ansatz: C++ registriert nur interne Kommandos.
 *   tcllitehtml::_init PATH WIDTH HEIGHT FONT SIZE
 *   tcllitehtml::_load PATH HTML
 *   tcllitehtml::_scroll PATH DY
 *   tcllitehtml::_destroy PATH
 *
 * Die öffentliche API (tcllitehtml::widget, load, etc.)
 * kommt vom Tcl-Wrapper (widget-0.1.tm).
 */

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

#include "tcllitehtml.h"
#include "container_tk.h"

#include <cstdio>
#include <string>
#include <map>
#include <memory>

/* ================================================================== */
/* State per Widget-Pfad                                              */
/* ================================================================== */

struct WidgetState {
    Tcl_Interp                   *interp;   /* gespeichert für Resize etc. */
    std::shared_ptr<ContainerTk>  container;
    litehtml::document::ptr       doc;
    int   width, height, scroll_y;
    int   doc_height;
    std::string canvas;                     /* Stufe 2: Canvas-Pfad für yview-Calls */
    std::string bg, html_text, base_url;
    std::string yscrollcmd;
};

/* Globale Map: canvas-Pfad → State (unique_ptr → kein manuelles delete) */
static std::map<std::string, std::unique_ptr<WidgetState>> g_widgets;

/* Fehler-Helper: Exception → Tcl-Fehler + stderr */
static void set_tcl_error(Tcl_Interp *interp, const char *msg)
{
    Tcl_SetResult(interp, (char*)msg, TCL_VOLATILE);
}

/* Nur zeichnen — kein neu-Parsen, schnell für Scroll */
static int do_draw(WidgetState *ws)
{
    Tcl_Interp *interp = ws->interp;
    if (!ws->doc || ws->height <= 1) return TCL_OK;

    /* scroll_y nur noch state für InfoCmd, nicht mehr für draw-Offset.
     * Tk's Canvas yview verwaltet das Scrolling selbst. */
    int max_scroll = ws->doc_height - ws->height;
    if (max_scroll < 0) max_scroll = 0;
    if (ws->scroll_y > max_scroll) ws->scroll_y = max_scroll;
    if (ws->scroll_y < 0) ws->scroll_y = 0;

    /* Container im DOC-Koord-System bedienen — kein y-Offset.
     * begin_draw bekommt doc_height (für _bg-Rect) statt Viewport-Höhe. */
    ws->container->begin_draw(ws->width, ws->doc_height, 0, ws->bg);

    /* Clip = gesamter DOC-Bereich, damit kein Item geclippt wird */
    litehtml::position clip(0, 0, ws->width, ws->doc_height);
    ws->doc->draw((litehtml::uint_ptr)ws->container.get(),
                  0, 0, &clip);          /* y=0 statt -scroll_y */
    ws->container->end_draw();

    /* Background-Rect (Tag _bg) auf doc-Höhe vergrößern */
    {
        char cmd[256];
        snprintf(cmd, sizeof(cmd),
            "%s coords _bg 0 0 %d %d",
            ws->canvas.c_str(), ws->width, ws->doc_height);
        Tcl_Eval(interp, cmd);
    }

    /* Scrollregion setzen — Tk's natives yview wird verfügbar */
    {
        char cmd[256];
        snprintf(cmd, sizeof(cmd),
            "%s configure -scrollregion {0 0 %d %d}",
            ws->canvas.c_str(), ws->width, ws->doc_height);
        Tcl_Eval(interp, cmd);
    }

    /* yscrollcommand machen wir Tk selbst überlassen (über
     * -yscrollcommand auf dem Canvas, siehe widget.tm).
     * Der alte hier-im-C++-yscrollcmd-Fallback entfällt. */
    return TCL_OK;
}

/* HTML parsen + Layout + Zeichnen */
static int do_render(WidgetState *ws)
{
    Tcl_Interp *interp = ws->interp;
    if (ws->html_text.empty() || ws->height <= 1) return TCL_OK;
    try {
        /* baseurl vor createFromString setzen — import_css braucht sie */
        if (!ws->base_url.empty()) {
            ws->container->reset_base_url();
            ws->container->set_external_base_url(ws->base_url.c_str());
        }
        /* User-CSS: fehlende UA-Margins ergänzen (Firefox-kompatibel) */
        static const char *user_css =
            "dd { margin-top: 0.5em; margin-bottom: 0.5em; }"
            "dt { margin-top: 0.5em; }";
        ws->doc = litehtml::document::createFromString(
            ws->html_text.c_str(), ws->container.get(), 
            litehtml::master_css, user_css);
        if (!ws->doc) {
            set_tcl_error(interp, "createFromString fehlgeschlagen");
            return TCL_ERROR;
        }
        ws->doc->render(ws->width);
        ws->doc_height = ws->doc->height();
        if (ws->doc_height < ws->height) ws->doc_height = ws->height;
        return do_draw(ws);
    } catch (const std::exception& e) {
        set_tcl_error(interp, e.what());
        return TCL_ERROR;
    } catch (...) {
        set_tcl_error(interp, "unbekannte C++-Exception");
        return TCL_ERROR;
    }
}

/* ================================================================== */
/* tcllitehtml::_init CANVAS WIDTH HEIGHT FONT FONTSIZE BG           */
/* ================================================================== */

static int InitCmd(ClientData, Tcl_Interp *interp,
                   int objc, Tcl_Obj *const objv[])
{
    if (objc < 7) {
        Tcl_WrongNumArgs(interp, 1, objv,
            "canvas width height font fontsize bg ?yscrollcmd?");
        return TCL_ERROR;
    }
    std::string path = Tcl_GetString(objv[1]);
    int w, h, fs;
    Tcl_GetIntFromObj(interp, objv[2], &w);
    Tcl_GetIntFromObj(interp, objv[3], &h);
    std::string font = Tcl_GetString(objv[4]);
    Tcl_GetIntFromObj(interp, objv[5], &fs);
    std::string bg          = Tcl_GetString(objv[6]);
    std::string yscrollcmd  = (objc >= 8) ? Tcl_GetString(objv[7]) : "";
    std::string on_link_click = (objc >= 9) ? Tcl_GetString(objv[8]) : "";

    /* Alten State ggf. löschen */
    auto it = g_widgets.find(path);
    if (it != g_widgets.end()) {
        g_widgets.erase(it);
    }

    auto ws_ptr = std::make_unique<WidgetState>();
    WidgetState *ws = ws_ptr.get();
    ws->interp     = interp;
    ws->canvas     = path;                  /* Stufe 2 */
    ws->width      = w;
    ws->height     = h;
    ws->scroll_y   = 0;
    ws->doc_height = h;
    ws->bg         = bg;
    ws->yscrollcmd = yscrollcmd;
    ws->container = std::make_shared<ContainerTk>(interp, path, font, fs);
    ws->container->set_on_link_click(on_link_click);
    g_widgets[path] = std::move(ws_ptr);
    return TCL_OK;
}

/* ================================================================== */
/* tcllitehtml::_load CANVAS HTML                                     */
/* ================================================================== */

static int LoadCmd(ClientData, Tcl_Interp *interp,
                   int objc, Tcl_Obj *const objv[])
{
    if (objc < 3) {
        Tcl_WrongNumArgs(interp, 1, objv, "canvas html");
        return TCL_ERROR;
    }
    std::string path = Tcl_GetString(objv[1]);
    auto it = g_widgets.find(path);
    if (it == g_widgets.end()) {
        Tcl_SetResult(interp, (char*)"unknown widget", TCL_STATIC);
        return TCL_ERROR;
    }
    WidgetState *ws = it->second.get();
    ws->html_text = Tcl_GetString(objv[2]);
    ws->scroll_y  = 0;
    return do_render(ws);
}

/* ================================================================== */
/* tcllitehtml::_scroll CANVAS DY                                    */
/* ================================================================== */


static int ScrollToCmd(ClientData, Tcl_Interp *interp,
                       int objc, Tcl_Obj *const objv[])
{
    if (objc < 3) {
        Tcl_WrongNumArgs(interp, 1, objv, "path abs_y");
        return TCL_ERROR;
    }
    std::string path = Tcl_GetString(objv[1]);
    auto it = g_widgets.find(path);
    if (it == g_widgets.end()) return TCL_OK;
    int abs_y = 0;
    Tcl_GetIntFromObj(interp, objv[2], &abs_y);
    WidgetState *ws = it->second.get();
    ws->scroll_y = abs_y;
    /* Stufe 2: kein do_draw mehr — Canvas-yview macht das Scrolling.
     * Tcl-Layer ruft "$canvas yview moveto ..." selbst. */
    return TCL_OK;
}

static int ScrollCmd(ClientData, Tcl_Interp *interp,
                     int objc, Tcl_Obj *const objv[])
{
    if (objc < 3) return TCL_OK;
    std::string path = Tcl_GetString(objv[1]);
    auto it = g_widgets.find(path);
    if (it == g_widgets.end()) return TCL_OK;
    int dy; Tcl_GetIntFromObj(interp, objv[2], &dy);
    it->second.get()->scroll_y += dy;
    /* Stufe 2: kein do_draw mehr */
    return TCL_OK;
}

/* ================================================================== */
/* tcllitehtml::_destroy CANVAS                                       */
/* ================================================================== */

static int DestroyCmd(ClientData, Tcl_Interp * /*interp*/,
                      int objc, Tcl_Obj *const objv[])
{
    if (objc < 2) return TCL_OK;
    std::string path = Tcl_GetString(objv[1]);
    g_widgets.erase(path);  /* unique_ptr → automatisches delete */
    return TCL_OK;
}

/* ================================================================== */
/* Package init                                                       */
/* ================================================================== */


/* ================================================================== */
/* tcllitehtml::_resize PATH WIDTH HEIGHT                            */
/* ================================================================== */

static int ResizeCmd(ClientData, Tcl_Interp *interp,
                     int objc, Tcl_Obj *const objv[])
{
    if (objc < 4) {
        Tcl_WrongNumArgs(interp, 1, objv, "path width height");
        return TCL_ERROR;
    }
    std::string path = Tcl_GetString(objv[1]);
    auto it = g_widgets.find(path);
    if (it == g_widgets.end()) return TCL_OK;
    int w, h;
    Tcl_GetIntFromObj(interp, objv[2], &w);
    Tcl_GetIntFromObj(interp, objv[3], &h);
    it->second.get()->width  = w;
    it->second.get()->height = h;
    /* Bei Resize: Cache leeren + neu parsen (Breite kann sich ändern) */
    if (it->second.get()->container)
        it->second.get()->container->clear_width_cache();
    return do_render(it->second.get());
}

/* ================================================================== */
/* tcllitehtml::_info PATH key                                       */
/* ================================================================== */

static int InfoCmd(ClientData, Tcl_Interp *interp,
                   int objc, Tcl_Obj *const objv[])
{
    if (objc < 3) {
        Tcl_WrongNumArgs(interp, 1, objv, "path key");
        return TCL_ERROR;
    }
    std::string path = Tcl_GetString(objv[1]);
    std::string key  = Tcl_GetString(objv[2]);
    auto it = g_widgets.find(path);
    if (it == g_widgets.end()) {
        Tcl_SetResult(interp, (char*)"unknown widget", TCL_STATIC);
        return TCL_ERROR;
    }
    if (key == "doc_height") {
        Tcl_SetObjResult(interp, Tcl_NewIntObj(it->second.get()->doc_height));
    } else if (key == "scroll_y") {
        Tcl_SetObjResult(interp, Tcl_NewIntObj(it->second.get()->scroll_y));
    } else if (key == "width") {
        Tcl_SetObjResult(interp, Tcl_NewIntObj(it->second.get()->width));
    } else if (key == "height") {
        Tcl_SetObjResult(interp, Tcl_NewIntObj(it->second.get()->height));
    } else {
        Tcl_SetResult(interp, (char*)"unknown key", TCL_STATIC);
        return TCL_ERROR;
    }
    return TCL_OK;
}



/* tcllitehtml::_setimage PATH URL PHOTO
 * Setzt ein Tk-Photo-Bild für eine URL (für externe/async Bilder) */
static int SetImageCmd(ClientData, Tcl_Interp *interp,
                       int objc, Tcl_Obj *const objv[])
{
    if (objc < 4) {
        Tcl_WrongNumArgs(interp, 1, objv, "path url photo");
        return TCL_ERROR;
    }
    std::string path  = Tcl_GetString(objv[1]);
    std::string url   = Tcl_GetString(objv[2]);
    std::string photo = Tcl_GetString(objv[3]);
    auto it = g_widgets.find(path);
    if (it == g_widgets.end()) return TCL_OK;
    WidgetState *ws = it->second.get();
    if (ws->container) ws->container->set_image(url, photo);
    /* Neu zeichnen damit das Bild erscheint */
    return do_draw(ws);
}

/* ================================================================== */
/* tcllitehtml::_click PATH DOC_X DOC_Y                              */
/* Maus-Klick → on_lbutton_up → on_anchor_click                     */
/* Stufe 2: Tcl-Layer übergibt schon DOC-Koords (via [$cv canvasy]). */
/* ================================================================== */

static int ClickCmd(ClientData, Tcl_Interp *interp,
                    int objc, Tcl_Obj *const objv[])
{
    if (objc < 4) {
        Tcl_WrongNumArgs(interp, 1, objv, "path doc_x doc_y");
        return TCL_ERROR;
    }
    std::string path = Tcl_GetString(objv[1]);
    auto it = g_widgets.find(path);
    if (it == g_widgets.end()) return TCL_OK;
    WidgetState *ws = it->second.get();
    if (!ws->doc) return TCL_OK;

    int doc_x, doc_y;
    Tcl_GetIntFromObj(interp, objv[2], &doc_x);
    Tcl_GetIntFromObj(interp, objv[3], &doc_y);

    /* client_x/y bekommt litehtml für :hover etc. — wir geben einfach
     * dieselben Werte; da nicht mehr im Viewport-System gerechnet wird,
     * ist die Unterscheidung kosmetisch */
    int cx = doc_x;
    int cy = doc_y;

    litehtml::position::vector redraw_boxes;
    /* litehtml braucht down VOR up damit on_anchor_click feuert */
    ws->doc->on_lbutton_down(doc_x, doc_y, cx, cy, redraw_boxes);
    redraw_boxes.clear();
    if (ws->doc->on_lbutton_up(doc_x, doc_y, cx, cy, redraw_boxes)) {
        do_draw(ws);
    }
    return TCL_OK;
}

/* tcllitehtml::_mouse PATH DOC_X DOC_Y (für hover) */
static int MouseCmd(ClientData, Tcl_Interp *interp,
                    int objc, Tcl_Obj *const objv[])
{
    if (objc < 4) return TCL_OK;
    std::string path = Tcl_GetString(objv[1]);
    auto it = g_widgets.find(path);
    if (it == g_widgets.end()) return TCL_OK;
    WidgetState *ws = it->second.get();
    if (!ws->doc) return TCL_OK;

    int doc_x, doc_y;
    Tcl_GetIntFromObj(interp, objv[2], &doc_x);
    Tcl_GetIntFromObj(interp, objv[3], &doc_y);
    int cx = doc_x;
    int cy = doc_y;

    litehtml::position::vector redraw_boxes;
    if (ws->doc->on_mouse_over(doc_x, doc_y, cx, cy, redraw_boxes)) {
        do_draw(ws);
    }
    return TCL_OK;
}


static int SetBaseUrlCmd(ClientData, Tcl_Interp *interp,
                         int objc, Tcl_Obj *const objv[])
{
    if (objc < 3) {
        Tcl_WrongNumArgs(interp, 1, objv, "path url");
        return TCL_ERROR;
    }
    std::string path = Tcl_GetString(objv[1]);
    auto it = g_widgets.find(path);
    if (it == g_widgets.end()) return TCL_OK;
    it->second->base_url = Tcl_GetString(objv[2]);
    if (it->second->container) {
        it->second->container->reset_base_url();
        it->second->container->set_external_base_url(it->second->base_url.c_str());
    }
    return TCL_OK;
}

static int GetTextCmd(ClientData, Tcl_Interp *interp,
                      int objc, Tcl_Obj *const objv[])
{
    if (objc < 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "path ?x1 y1 x2 y2?");
        return TCL_ERROR;
    }
    std::string path = Tcl_GetString(objv[1]);
    auto it = g_widgets.find(path);
    if (it == g_widgets.end()) return TCL_OK;
    WidgetState *ws = it->second.get();
    if (!ws->container) return TCL_OK;

    std::string text;
    if (objc >= 6) {
        int x1, y1, x2, y2;
        Tcl_GetIntFromObj(interp, objv[2], &x1);
        Tcl_GetIntFromObj(interp, objv[3], &y1);
        Tcl_GetIntFromObj(interp, objv[4], &x2);
        Tcl_GetIntFromObj(interp, objv[5], &y2);
        y1 += ws->scroll_y;
        y2 += ws->scroll_y;
        text = ws->container->get_text_in_rect(x1, y1, x2, y2);
    } else {
        text = ws->container->get_text_in_rect(
            0, 0, ws->width, ws->doc_height + ws->height);
    }
    Tcl_SetObjResult(interp, Tcl_NewStringObj(text.c_str(), -1));
    return TCL_OK;
}


extern "C" int Tcllitehtml_Init(Tcl_Interp *interp)
{
#if TCL_MAJOR_VERSION >= 9
    if (Tcl_InitStubs(interp, "9.0", 0) == NULL) return TCL_ERROR;
    if (Tk_InitStubs(interp,  "9.0", 0) == NULL) return TCL_ERROR;
#else
    if (Tcl_InitStubs(interp, "8.1", 0) == NULL) return TCL_ERROR;
    if (Tk_InitStubs(interp,  "8.1", 0) == NULL) return TCL_ERROR;
#endif

    Tcl_CreateObjCommand(interp, "tcllitehtml::_init",    InitCmd,    NULL, NULL);
    Tcl_CreateObjCommand(interp, "tcllitehtml::_load",    LoadCmd,    NULL, NULL);
    Tcl_CreateObjCommand(interp, "tcllitehtml::_scrollto",  ScrollToCmd,   NULL, NULL);
    Tcl_CreateObjCommand(interp, "tcllitehtml::_scroll",  ScrollCmd,  NULL, NULL);
    Tcl_CreateObjCommand(interp, "tcllitehtml::_destroy", DestroyCmd, NULL, NULL);
    Tcl_CreateObjCommand(interp, "tcllitehtml::_resize",  ResizeCmd,  NULL, NULL);
    Tcl_CreateObjCommand(interp, "tcllitehtml::_info",    InfoCmd,    NULL, NULL);
    Tcl_CreateObjCommand(interp, "tcllitehtml::_click",    ClickCmd,    NULL, NULL);
    Tcl_CreateObjCommand(interp, "tcllitehtml::_setimage", SetImageCmd, NULL, NULL);
    Tcl_CreateObjCommand(interp, "tcllitehtml::_gettext",    GetTextCmd,      NULL, NULL);
    Tcl_CreateObjCommand(interp, "tcllitehtml::_setbaseurl", SetBaseUrlCmd,   NULL, NULL);
    Tcl_CreateObjCommand(interp, "tcllitehtml::_mouse",   MouseCmd,   NULL, NULL);

    Tcl_PkgProvide(interp, "tcllitehtml", TCLLITEHTML_VERSION);
    return TCL_OK;
}
