# tcllitehtml API Reference

**Version:** 0.1.0 (Unreleased — with Stufe 1+2 performance refactor)

---

## Creating a Widget

```tcl
tcllitehtml::widget PATH ?OPTIONS?
```

Creates an HTML widget (internally a Tk Canvas).

### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `-width N` | int | 800 | Width in pixels |
| `-height N` | int | 0 | Height (0 = fill both) |
| `-background COLOR` | color | white | Background color |
| `-font NAME` | string | Sans/Arial | Default font family |
| `-fontsize N` | int | 13 | Default font size in pixels |
| `-yscrollcommand CMD` | callback | "" | Scrollbar callback (Tk-native) |
| `-command CMD` | callback | "" | Link click callback (receives URL) |
| `-openurl 1` | bool | 0 | Auto-open http links (xdg-open / start) |

### Example

```tcl
package require tcllitehtml

frame .f
pack .f -fill both -expand 1

scrollbar .f.sb -orient vertical -command {.f.html yview}
tcllitehtml::widget .f.html \
    -background white \
    -yscrollcommand {.f.sb set} \
    -openurl 1
pack .f.sb   -side right -fill y
pack .f.html -side left  -fill both -expand 1
```

---

## Widget Commands

### load

```tcl
PATH load HTML
PATH load -file PATH
```

Loads and renders an HTML string or file. Triggers a full
re-render — the entire document is drawn onto the canvas in
document coordinates.

```tcl
.html load {<h1>Hello</h1><p>World</p>}
.html load -file /path/to/help.html
```

### yview

```tcl
PATH yview
PATH yview moveto FRACTION
PATH yview scroll N units|pages
```

Scrolls the widget. Standard Tk scrollbar interface.

```tcl
.html yview                ;# returns {first last} fractions
.html yview moveto 0.0     ;# scroll to top
.html yview moveto 0.5     ;# scroll to middle
.html yview scroll 3 units ;# scroll down 3 units
.html yview scroll -1 pages;# scroll up one page
```

**Performance note:** As of the Stufe-2 refactor, `yview` is
delegated directly to the underlying Tk canvas — no re-render
happens during scrolling. Each scroll tick is well under 1 ms
even for large documents. See [performance.md](performance.md).

### cget

```tcl
PATH cget OPTION
```

| Option | Returns |
|--------|---------|
| `-width` | Width in pixels |
| `-height` | Height in pixels |
| `-background` | Background color |
| `-font` | Font name |
| `-fontsize` | Font size |
| `-command` | Link callback |
| `-yscrollcommand` | Scrollbar callback |
| `-canvas` | Internal canvas command name (for bbox, create etc.) |

```tcl
set cv [.html cget -canvas]   ;# e.g. ::tcllitehtml::_cv_f_html

# For pdf4tcl: use widget path directly, not $cv!
# $pdf canvas .f.html   ;# OK
# $pdf canvas $cv       ;# NO — bad window path name
```

### configure

```tcl
PATH configure OPTION VALUE
```

Reconfigures the widget. Backend options (font, fontsize, background)
trigger a full re-render.

```tcl
.html configure -background #f0f0f0
.html configure -fontsize 15
```

---

## Link Handling

```tcl
# Auto-open in browser
tcllitehtml::widget .html -openurl 1

# Custom callback
tcllitehtml::widget .html -command {apply {{url} {
    if {[string match "http*" $url]} {
        exec xdg-open $url &
    }
}}}
```

---

## Text Selection

```tcl
# Activate selection mode (bindings + crosshair cursor)
tcllitehtml::selection_start .html

# Deactivate
tcllitehtml::selection_stop .html

# Keyboard shortcuts (always active):
# Ctrl+A  select all
# Ctrl+C  copy selection
```

Click = select word, double-click = select line, drag = range.
Selected text is copied to clipboard and X11 PRIMARY selection.

---

## Internal Commands

Not normally called directly — used by the widget wrapper.

> **Stufe-2 change:** `_scroll` and `_scrollto` are now state-only
> commands. They update the C++ `scroll_y` state but **do not**
> trigger a re-render. Actual scrolling happens via the canvas'
> native `yview`. The widget wrapper takes care of both sides.

### _scroll

```tcl
tcllitehtml::_scroll PATH DY
```

Adjusts the internal `scroll_y` state by `DY` pixels. No re-render.
The widget wrapper's mouse-wheel bindings call `$cv yview scroll`
in parallel — this updates `scroll_y` mostly for the `_info` API.

### _scrollto

```tcl
tcllitehtml::_scrollto PATH ABS_Y
```

Sets `scroll_y` to an absolute pixel position. No re-render. Like
`_scroll`, mostly used for state tracking; `yview moveto` actually
moves the canvas.

### _info

```tcl
tcllitehtml::_info PATH KEY
```

Returns a single value for the given key:

```tcl
set doc_height [tcllitehtml::_info .html doc_height]
set width      [tcllitehtml::_info .html width]
set scroll_y   [tcllitehtml::_info .html scroll_y]
set height     [tcllitehtml::_info .html height]
```

### _setbaseurl

```tcl
tcllitehtml::_setbaseurl PATH URL
```

Sets the base URL for relative CSS / image resolution.
Call before `load` when displaying remote HTML.

```tcl
tcllitehtml::_setbaseurl .html https://example.com/docs/page.html
.html load $html_content
```

### _setimage

```tcl
tcllitehtml::_setimage PATH URL IMAGENAME
```

Injects a Tk photo image for a URL (for dynamic image loading).

```tcl
set img [image create photo -file logo.png]
tcllitehtml::_setimage .html https://example.com/logo.png $img
```

### _click / _mouse

```tcl
tcllitehtml::_click  PATH DOC_X DOC_Y
tcllitehtml::_mouse  PATH DOC_X DOC_Y
```

Click and hover events. **Stufe 2:** these expect **document
coordinates**, not window coordinates. The widget's bindings convert
the raw `%y` from Tk via `[$canvas canvasy %y]` (and `[expr {int(...)}]`
to satisfy the strict `Tcl_GetIntFromObj` on the C side). The helper
procs `::tcllitehtml::_click_event` and `::tcllitehtml::_motion_event`
in `widget-0.1.tm` encapsulate this conversion.

---

## PDF Export

Requires pdf4tcl. Uses the Tk Window Path (not `$cv`):

```tcl
package require pdf4tcl
update idletasks

set bbox [.f.html bbox all]
lassign $bbox x1 y1 x2 y2
set cw   [expr {$x2 - $x1}]
set ch   [expr {$y2 - $y1}]

# fontmap for Unicode (DejaVu covers ✔ etc.)
set fontmap {}
foreach {tk ttf} {
    Helvetica /usr/share/fonts/truetype/dejavu/DejaVuSans.ttf
    Courier   /usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf
} { if {[file exists $ttf]} { lappend fontmap $tk $ttf } }

set scale [expr {555.0 / $cw}]
set ph    [expr {int($ch * $scale + 40)}]

set pdf [::pdf4tcl::new %AUTO% -paper [list 595 $ph] -orient true -compress 1]
$pdf startPage
$pdf canvas .f.html -fontmap $fontmap \
    -bbox $bbox -x 20 -y 20 -width 555 -height [expr {$ph - 40}]
$pdf endPage
$pdf write -file output.pdf
$pdf destroy
```

**Note:** Since Stufe 2 the canvas contains the full document (all
items in document coordinates), so `[.f.html bbox all]` returns the
real document bounds — not just the viewport. This makes multi-page
export plausible: clip the bbox per page and call `$pdf canvas` with
the matching slice for each page. The shipped `demo-pdf.tcl` still
does the simple 1-page variant.

---

## Known Limitations

| Feature | Status | Notes |
|---------|--------|-------|
| Fragment links `#id` | not yet | Phase 2: needs `_getpos id` |
| Multi-page PDF export | not yet | Possible since Stufe 2 — not implemented in demos |
| `overflow:hidden` | not supported | No real clipping in Tk Canvas |
| CSS gradients | not supported | First stop color used as fallback |
| `opacity` | not supported |   |
| Flexbox / Grid | not supported | litehtml limitation |
| `background-repeat` | not supported | No tiling |
| JavaScript | not supported | Not planned |
| Forms | not yet | Phase 3 |

---

## litehtml Version

Uses `github.com/litehtml/litehtml` master branch. Vendor checkout
is done by `make litehtml`; pin to a specific commit by setting
`LITEHTML_REF` if needed.

Two patches are applied automatically:

| File | Fix |
|------|-----|
| `src/web_color.cpp` | Remove `resolve_color()` recursion |
| `include/litehtml/font_description.h` | Initialise `weight`, simplify `hash()` |
