# tcllitehtml — Architecture

## Overview

```
App (Tcl)
    |
tcllitehtml::widget       (tcl/tcllitehtml/widget-0.1.tm)
    |   Tcl wrapper: options, bindings, helper procs,
    |   resize debounce, selection
    |
tcllitehtml C++ extension (src/tcllitehtml.cpp)
    |   Commands: _init, _load, _resize, _scroll, _scrollto,
    |             _click, _mouse, _info, _setimage, _setbaseurl,
    |             _gettext, _destroy
    |
litehtml                  (vendor/litehtml/)
    |   HTML5 parser (gumbo), CSS2/3 engine, layout
    |
ContainerTk               (src/container_tk.cpp)
    |   Implements litehtml::document_container.
    |   Translates draw_* calls into Tk Canvas commands.
    |
Tk Canvas                 (rendering backend)
```

## Key Design Decisions

### Canvas as Rendering Backend

litehtml calls `draw_text`, `draw_solid_fill`, `draw_borders`,
`draw_image` with pixel-exact coordinates. ContainerTk translates
these into `canvas create text/rectangle/line/image` commands.

The entire document is laid out and drawn onto the canvas in
**document coordinates** (`y` from 0 to `doc_height`). The Tk canvas
itself takes care of clipping and scrolling — see _Coordinate
System_ below.

### Widget Identity (rename trick)

```tcl
canvas $path                                   ;# create as .f.html
rename $path $cv                               ;# rename Tcl command
                                               ;# → ::tcllitehtml::_cv_f_html
interp alias {} $path {} _dispatch $path $cv   ;# .f.html → dispatcher
```

Result:

- `.f.html` — Tk window path; still valid for `winfo`, `pdf4tcl`,
  `pack`, `bind` etc.
- `$cv` — Tcl command name for direct canvas subcommands
  (`bbox`, `create`, `find`, `yview`, …)

The widget dispatcher forwards most calls to `$cv`, but intercepts
`load`, `configure`, `cget`, etc. — Tk users see a normal-looking
widget.

### Coordinate System (Stufe 2)

```
litehtml: y=0 top, grows downward (pixels)
Tk Canvas: y=0 top, grows downward (pixels)
→ No Y-flip needed for rendering.

Stufe 2: tcllitehtml stores document items at document coordinates.

    doc->draw(container, 0, 0, &clip)
    clip = (0, 0, width, doc_height)

    ContainerTk::draw_text gets pos.y = document y
    ContainerTk emits:  $canvas create text $x $y -text "..." ...

After all draw_* calls:
    $canvas configure -scrollregion {0 0 width doc_height}

Scrolling:
    bind $widget <MouseWheel> "$cv yview scroll -%D units"
    bind $widget <Button-1>   {::tcllitehtml::_click_event %W %x %y}

    _click_event converts the Tk window %y into a document y:
        set doc_y [expr {int([$cv canvasy %y])}]
        tcllitehtml::_click $path %x $doc_y

    The C-side _click expects integer document coords — that's why
    the explicit int() cast: canvasy returns a float.
```

This is the architectural shift introduced in Stufe 2:

| Before Stufe 2 | Stufe 2 |
|----------------|---------|
| Canvas held only the visible viewport | Canvas holds the full document |
| Every scroll tick → `canvas delete all` + re-render | Scroll is a Tk-internal pan; no re-render |
| `draw_text` got screen coordinates (y already offset by `-scroll_y`) | `draw_text` gets document coordinates |
| `_click` did `doc_y = window_y + scroll_y` | `_click` receives document y directly |
| Off-screen clipping done in `draw_text` (`y > _height return`) | Off-screen clipping done by Tk Canvas |

The trade-off: the canvas holds **all** items even off-screen — a
few MB of Canvas-item state for a 2000-px document with ~300 items.
That's a deliberate exchange of memory for scroll smoothness.

### Re-Render Triggers

Re-rendering means calling `do_render()` (full litehtml parse +
layout + container draw cycle). It happens on:

- `_load` (new HTML supplied)
- `_resize` (width or height changed) — debounced by 100 ms in
  `widget-0.1.tm`
- `configure -font` / `-fontsize` / `-background` (forces full
  re-layout because metrics change)
- `_click` returning a litehtml redraw flag (`on_lbutton_up` returned
  true — e.g. `:hover` causing a layout shift)

It does **not** happen on:

- `yview scroll`, `yview moveto` — Tk's canvas handles it
- `_scroll`, `_scrollto` — state-only, no draw
- Mouse motion that doesn't shift layout

### CSS Import

CSS files are loaded via `import_css()` using Tcl's `http::geturl`.
A CSS cache prevents multiple fetches of the same URL. The base URL
is stored externally to prevent litehtml from overwriting it.

## Files

| File | Purpose |
|------|---------|
| `src/tcllitehtml.cpp` | C++ commands, `WidgetState`, `do_render` / `do_draw` |
| `src/container_tk.cpp` | `ContainerTk`: all `draw_*` methods, `import_css`, text-log for selection |
| `src/container_tk.h` | `ContainerTk` header, `TextItem` struct |
| `src/tcllitehtml.h` | Shared declarations |
| `tcl/tcllitehtml/widget-0.1.tm` | Tcl widget wrapper, bindings, debounce, helper procs |
| `tcl/tcllitehtml/pkgIndex.tcl` | Package index (Tcl-version + platform detection) |
| `pkgIndex-flat.tcl` | Flat-install variant of the package index (one directory) |
| `Makefile` | Linux build, depends on `vendor/litehtml/` |
| `build-win.bat` | Windows build (BAWT) |

## Performance Characteristics

See [performance.md](performance.md) for measurements.

Quick summary:

| Operation | Time | Cost source |
|-----------|------|-------------|
| Initial load + render | ~750 ms for ~300 items | Tk canvas item allocation (~1 ms/item) |
| Scroll tick | < 1 ms | Tk-native pan |
| Resize during drag | 0 ms | Debounced (100 ms) |
| Resize after release | ~150 ms | litehtml re-layout + full re-draw |
| `configure -fontsize` | ~150 ms | Full re-layout + re-draw |
