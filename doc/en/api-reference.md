# tcllitehtml API Reference

**Version:** 0.1.0

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
| `-yscrollcommand CMD` | callback | "" | Scrollbar callback |
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

Loads and renders an HTML string or file.

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
.html yview moveto 0.0     ;# scroll to top (absolute)
.html yview moveto 0.5     ;# scroll to middle
.html yview scroll 3 units ;# scroll down 3 units (relative)
```

**Note:** `moveto` uses `_scrollto` (absolute positioning) internally —
Scrollbar drag works correctly. `scroll` uses relative offset.

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
# $pdf canvas .f.html   ;# ✔
# $pdf canvas $cv       ;# ✗ bad window path name
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

### _scrollto

```tcl
tcllitehtml::_scrollto PATH ABS_Y
```

Scrolls to an absolute pixel position. Used internally by `yview moveto`.
Unlike `_scroll` (which adds a relative offset), `_scrollto` sets
`scroll_y` directly — required for correct scrollbar drag behavior.

---

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

Sets the base URL for relative CSS/image resolution.
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

---

## PDF Export (1 page)

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

**Note:** Multi-page PDF is not yet supported — the canvas only
contains the visible area. See `nogit/html-pdf-md-research.md`.

---

## Known Limitations

| Feature | Status | Notes |
|---------|--------|-------|
| Fragment links `#id` | ✗ | Phase 2: `_getpos id` not yet implemented |
| Multi-page PDF export | ✗ | Canvas only renders visible area |
| `overflow:hidden` | ✗ | No real clipping in Tk Canvas |
| CSS gradients | ✗ | First stop color used as fallback |
| `opacity` | ✗ | Not supported |
| Flexbox / Grid | ✗ | litehtml limitation |
| `background-repeat` | ✗ | No tiling |
| JavaScript | ✗ | Not planned |
| Forms | ✗ | Phase 3 |

---

## litehtml Version

Uses `github.com/litehtml/litehtml` master branch (commit `8836bc1`).
No official version number — master branch.
