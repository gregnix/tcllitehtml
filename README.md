# tcllitehtml — HTML/CSS Widget for Tcl/Tk

A lightweight HTML/CSS rendering widget for Tcl/Tk applications,
built on [litehtml](https://github.com/litehtml/litehtml) (BSD).

**Platform:** Linux, Windows (BAWT)
**Tcl/Tk:** 8.6 or 9.0
**License:** BSD

---

## Features

- HTML5 + CSS2/3 rendering (tables, lists, fonts, colors, images)
- Tk-native scrolling via `$widget yview` (smooth at any document size)
- Debounced resize — no stuttering while dragging window edges
- Scrollbar (`-yscrollcommand`), mousewheel
- Link callbacks (`-command`, `-openurl`)
- Hover effects, cursor changes
- Local images (PPM, PNG, GIF via Tk photo)
- Dynamic images via `_setimage`
- Text selection, clipboard / PRIMARY support
- 1-page PDF export via pdf4tcl `canvas` adapter
- Tcl-Canvas backend — no extra dependencies
- Tested: Linux + Windows, Tcl/Tk 8.6 + 9.0

---

## Quick Start

```bash
# 1. Clone tcllitehtml
git clone https://github.com/gregnix/tcllitehtml.git
cd tcllitehtml

# 2. Fetch litehtml (one time)
make litehtml

# 3. Build (Tcl 8.6 by default)
make

# 4. Run demo
wish demos/demo-basic.tcl
```

**Tcl 9.0:**
```bash
make tcl9
wish9.0 demos/demo-basic.tcl
```

**Windows (BAWT 3.2):**
```cmd
git clone https://github.com/gregnix/tcllitehtml.git
cd tcllitehtml
git clone --depth=1 https://github.com/litehtml/litehtml vendor\litehtml
build-win.bat 86
wish demos\demo-basic.tcl
```

See [INSTALL.md](INSTALL.md) for installation into user-local Tcl
module paths (Linux + Windows).

---

## Usage

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

# Load inline HTML
.f.html load {<h1>Hallo</h1><p>Ein <b>HTML</b>-Widget.</p>}

# Load from file
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
| `-fontsize N` | 13 | Default font size |
| `-yscrollcommand CMD` | "" | Scrollbar callback (Tk-native) |
| `-command CMD` | "" | Link click callback (receives URL) |
| `-openurl 1` | "" | Auto-open http links in browser |

---

## Widget Commands

```tcl
.html load HTML              ;# load HTML string
.html load -file PATH        ;# load HTML file
.html yview moveto 0.0       ;# scroll to top
.html yview scroll 3 units   ;# scroll down (Tk-native, no re-render)
.html cget -width            ;# get option
.html configure -fontsize 15 ;# triggers re-render
```

See [doc/en/api-reference.md](doc/en/api-reference.md) for the full
command reference.

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
tcllitehtml::widget       (tcl/tcllitehtml/widget-0.1.tm)
    |
tcllitehtml C++ extension (src/tcllitehtml.cpp)
    |
litehtml — HTML/CSS Parser + Layout Engine (BSD)
    |
ContainerTk               (src/container_tk.cpp)
    |
Tk Canvas — rendering backend
```

Documents are rendered to the canvas in **document coordinates** (the
full document, not just the visible region). Scrolling is handled by
Tk's native `canvas yview` mechanism — no per-tick re-render. See
[doc/en/architecture.md](doc/en/architecture.md) and
[doc/en/performance.md](doc/en/performance.md).

---

## Building

### Linux

```bash
# Dependencies:
sudo apt install tcl8.6-dev tk8.6-dev tcl9.0-dev tk9.0-dev g++ cmake git

# Build:
make           # Tcl 8.6
make tcl9      # Tcl 9.0

# Test:
make test
make test9
```

### Windows (BAWT 3.2)

```cmd
build-win.bat 86   :: Tcl 8.6
build-win.bat 90   :: Tcl 9.0
test-win.bat
```

See [doc/en/windows-build.md](doc/en/windows-build.md) for the full
Windows build procedure.

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
wish demos/demo-browser.tcl  # Mini browser (toolbar + history)
wish demos/demo-selection.tcl # Text selection demo
wish demos/demo-pdf.tcl      # 1-page PDF export via pdf4tcl
```

---

## Tests

```bash
make test       # Linux Tcl 8.6
make test9      # Linux Tcl 9.0
test-win.bat    # Windows
```

Expected: `Total 18  Passed 18  Failed 0`

---

## Performance

Document of ~200-300 elements (medium-sized Wiki article):

| Operation | Time |
|-----------|------|
| Initial load + render | ~750 ms |
| Scroll tick (mousewheel) | < 1 ms |
| Resize during window drag | 0 ms (debounced) |
| Resize after release | ~150 ms (litehtml re-layout) |

Scrolling is Tk-native; no per-tick re-render. See
[doc/en/performance.md](doc/en/performance.md) for details.

---

## Status

| Feature | Status |
|---------|--------|
| HTML5 + CSS2/3 | ✔ |
| Tables (colspan/rowspan) | ✔ |
| Scrollbar + mousewheel (Tk-native) | ✔ |
| Links + hover | ✔ |
| Cursor (hand, text, …) | ✔ |
| Images (local) | ✔ |
| Images (dynamic via `_setimage`) | ✔ |
| Resize (debounced) | ✔ |
| Tcl 8.6 + 9.0 | ✔ |
| Linux + Windows | ✔ |
| Text selection / clipboard | ✔ |
| 1-page PDF export | ✔ (via pdf4tcl) |
| `background-repeat` | Phase 2 |
| Cairo backend | Phase 2 |
| Multi-page PDF export | Phase 2 |
| Forms | Phase 3 |
| Fragment links `#id` | Phase 2 |

---

## License

BSD — see LICENSE file.

litehtml: BSD — https://github.com/litehtml/litehtml
