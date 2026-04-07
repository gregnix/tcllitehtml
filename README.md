# tcllitehtml — HTML/CSS Widget for Tcl/Tk

A lightweight HTML/CSS rendering widget for Tcl/Tk applications,
built on [litehtml](https://github.com/litehtml/litehtml) (BSD).

**Platform:** Linux, Windows (BAWT)  
**Tcl/Tk:** 8.6 or 9.0  
**License:** BSD

---

## Features

- HTML5 + CSS2/3 rendering (tables, lists, fonts, colors, images)
- Scrollbar (-yscrollcommand), mousewheel
- Link callbacks (-command, -openurl)
- Hover effects, cursor changes
- Local images (PPM, PNG, GIF via Tk photo)
- Dynamic images via `_setimage`
- Resize via `<Configure>`
- Tk-Canvas backend — no extra dependencies
- Tested: Linux + Windows, Tcl/Tk 8.6 + 9.0

---

## Quick Start

```bash
# 1. Clone litehtml
git clone --depth=1 https://github.com/litehtml/litehtml vendor/litehtml

# 2. Build (Tcl 8.6)
make

# 3. Run demo
wish demos/demo-basic.tcl
```

**Tcl 9.0:**
```bash
make TCL_VER=9.0
wish9.0 demos/demo-basic.tcl
```

**Windows (BAWT):**
```cmd
git clone --depth=1 https://github.com/litehtml/litehtml vendor\litehtml
build-win.bat
wish demos\demo-basic.tcl
```

---

## Usage

```tcl
package require tcllitehtml

# Widget erstellen
frame .f
pack .f -fill both -expand 1

scrollbar .f.sb -orient vertical -command {.f.html yview}
tcllitehtml::widget .f.html \
    -background white \
    -yscrollcommand {.f.sb set} \
    -openurl 1
pack .f.sb   -side right -fill y
pack .f.html -side left  -fill both -expand 1

# HTML laden
.f.html load {<h1>Hallo</h1><p>Ein <b>HTML</b>-Widget.</p>}

# HTML aus Datei
.f.html load -file hilfe.html
```

---

## Widget Options

| Option | Default | Description |
|--------|---------|-------------|
| `-width N` | 800 | Width in pixels |
| `-height N` | 0 | Height (0 = fill both) |
| `-background COLOR` | white | Background color |
| `-font NAME` | Sans/Arial | Default font |
| `-fontsize N` | 13 | Default font size (also configurable via configure) |
| `-yscrollcommand CMD` | "" | Scrollbar callback |
| `-command CMD` | "" | Link click callback (receives URL) |
| `-openurl 1` | "" | Auto-open http links in browser (xdg-open/start) |

---

## Widget Commands

```tcl
.html load HTML              ;# load HTML string
.html load -file PATH        ;# load HTML file
.html yview moveto 0.0       ;# scroll to top
.html yview scroll 3 units   ;# scroll down
.html cget -width            ;# get option
```

---

## Link Handling

```tcl
# Auto-open in browser (xdg-open / start):
tcllitehtml::widget .html -openurl 1

# Custom handler:
tcllitehtml::widget .html -command {apply {{url} {
    if {[string match "page:*" $url]} {
        # internal navigation
    } elseif {[string match "http*" $url]} {
        exec xdg-open $url &
    }
}}}
```

---

## Architecture

```
App (Tcl)
    |
tcllitehtml::widget  (widget-0.1.tm)
    |
tcllitehtml C++ extension  (tcllitehtml.cpp)
    |
litehtml — HTML/CSS Parser + Layout Engine (BSD)
    |
ContainerTk  (container_tk.cpp)
    |
Tk Canvas — rendering backend
```

---

## Building

### Linux

```bash
# Dependencies:
sudo apt install tcl8.6-dev tk8.6-dev g++ cmake

# Build:
make           # Tcl 8.6
make TCL_VER=9.0  # Tcl 9.0

# Test:
make test
```

### Windows (BAWT 3.2)

```cmd
# Requirements: BAWT 3.2, Git, Python 3
build-win.bat      # Tcl 8.6
build-win.bat 90   # Tcl 9.0
test-win.bat
```

### litehtml Patches

Two patches are applied automatically during build:

| File | Fix |
|------|-----|
| `src/web_color.cpp` | Remove `resolve_color()` recursion |
| `include/litehtml/font_description.h` | Fix uninitialized `weight`, simplify `hash()` |

---

## Demos

```bash
wish demos/demo-basic.tcl    # Basic HTML + CSS
wish demos/demo-table.tcl    # Tables with colspan/rowspan
wish demos/demo-links.tcl    # Link callbacks
wish demos/demo-css.tcl      # CSS features
wish demos/demo-images.tcl   # Images
```

---

## Tests

```bash
make test       # Linux
test-win.bat    # Windows
# Expected: Total 18  Passed 18  Failed 0
```

---

## Status

| Feature | Status |
|---------|--------|
| HTML5 + CSS2/3 | ✔ |
| Tables (colspan/rowspan) | ✔ |
| Scrollbar + mousewheel | ✔ |
| Links + hover | ✔ |
| Cursor (hand, text, ...) | ✔ |
| Images (local) | ✔ |
| Images (dynamic via _setimage) | ✔ |
| Resize | ✔ |
| Tcl 8.6 + 9.0 | ✔ |
| Linux + Windows | ✔ |
| background-repeat | Phase 2 |
| Cairo backend | Phase 2 |
| Selection/Clipboard | ✔ |
| Forms | Phase 3 |
| PDF Export (1 page) | ✔ (via pdf4tcl canvas) |
| PDF Export (multi-page) | Phase 2 |

---

## License

BSD — see LICENSE file.

litehtml: BSD — https://github.com/litehtml/litehtml
