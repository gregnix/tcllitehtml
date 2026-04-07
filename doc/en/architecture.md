# tcllitehtml — Architecture

## Overview

```
App (Tcl)
    |
tcllitehtml::widget  (tcl/tcllitehtml/widget-0.1.tm)
    |   Tcl wrapper: options, scrollbar, selection, bindings
    |
tcllitehtml C++ extension  (src/tcllitehtml.cpp)
    |   Commands: _init, _load, _scroll, _resize, _click,
    |             _mouse, _info, _setimage, _setbaseurl, _gettext
    |
litehtml  (vendor/litehtml/)
    |   HTML5 parser (gumbo), CSS2/3 engine, layout
    |
ContainerTk  (src/container_tk.cpp)
    |   Implements litehtml::document_container
    |   Translates draw_* calls → Tk Canvas commands
    |
Tk Canvas  (rendering backend)
```

## Key Design Decisions

### Canvas as Rendering Backend

litehtml calls `draw_text`, `draw_solid_fill`, `draw_borders`, `draw_image`
with pixel-exact coordinates. ContainerTk translates these into
`canvas create text/rectangle/line/image` commands.

**Consequence:** The canvas only contains items for the **visible area**.
Scrolling calls `do_draw()` which deletes all items and redraws
the current viewport using `doc->draw(..., -scroll_y, ...)`.

### Widget Identity (rename trick)

```tcl
canvas $path                      ;# create as .f.html
rename $path $cv                  ;# rename Tcl command → ::tcllitehtml::_cv_f_html
interp alias {} $path {} _dispatch $path  ;# .f.html → dispatcher
```

Result:
- `.f.html` — Tk window path (still valid for winfo, pdf4tcl, pack)
- `$cv` — Tcl command name (for canvas subcommands: bbox, create, etc.)

### Coordinate System

```
litehtml: y=0 top, grows downward (pixels)
Tk Canvas: y=0 top, grows downward (pixels)
→ No Y-flip needed for rendering

Scroll: doc->draw(container, 0, -scroll_y, &clip)
        ContainerTk draws items at (pos.x, pos.y)
        pos.y is already a screen coordinate (not doc coordinate)
        → No additional scroll offset in draw_text etc.
```

### CSS Import

CSS files are loaded via `import_css()` which uses Tcl's `http::geturl`.
A CSS cache prevents multiple fetches of the same URL.
The base URL is stored externally to prevent litehtml from overwriting it.

## Files

| File | Purpose |
|------|---------|
| `src/tcllitehtml.cpp` | C++ commands, WidgetState, do_render/do_draw |
| `src/container_tk.cpp` | ContainerTk: all draw_* methods, import_css, text selection |
| `src/container_tk.h` | ContainerTk header, TextItem struct |
| `src/tcllitehtml.h` | Shared declarations |
| `tcl/tcllitehtml/widget-0.1.tm` | Tcl widget wrapper |
| `tcl/tcllitehtml/pkgIndex.tcl` | Package index (platform detection) |
