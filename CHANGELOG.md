# Changelog — tcllitehtml

## [Unreleased] — 2026-05-19

### Performance — Tk-native scrolling + resize debounce

Rendering is now **document-coordinate based**: the entire document is
drawn once onto the canvas (from `y=0` to `doc_height`). Scrolling is
handled by Tk's native `canvas yview` mechanism without any re-render.
Resize events are debounced through a 100-ms timer — nothing happens
during a window drag, the re-render runs once after release.

Measured against demo-2.tcl (~200-300 canvas items):

| Operation | Before | After | Factor |
|-----------|--------|-------|--------|
| Scroll tick | 24 ms | < 1 ms | ~25× |
| Resize during drag | per-pixel re-render | 0 ms (debounced) | — |
| Resize after release | 153 ms | ~150 ms | unchanged |
| Initial load + render | 751 ms | unchanged | — |

### Changed

- **`container_tk.cpp`**: off-screen clip removed in `draw_text`,
  `draw_rect_fill`, `draw_list_marker` — all items now drawn in
  document coordinates. `begin_draw` emits a `_bg` tag for the
  background rectangle (resized later by `do_draw`).
- **`tcllitehtml.cpp`**: `do_draw` renders the whole document
  (`clip = 0..doc_height`), sets `-scrollregion` on the canvas and
  resizes `_bg`. `ScrollCmd` / `ScrollToCmd` only update the
  `scroll_y` state — no re-render. `ClickCmd` / `MouseCmd` expect
  document coordinates (no `+ scroll_y` addition any more).
- **`widget-0.1.tm`**: mouse-wheel bindings call `$cv yview scroll`
  directly. Click / motion go through new helper procs
  `_click_event` / `_motion_event` (clean quoting; explicit `int()`
  cast on the `canvasy` result, which returns a float). `_dispatch
  yview` delegates to the canvas. `-yscrollcommand` is set directly
  on the canvas (Tk's native scrollbar protocol).
- **`widget-0.1.tm` `_on_configure`**: debounce via a 100-ms
  `after`-timer. New `_do_resize` proc for the deferred actual
  resize. `_on_destroy` cancels any pending timer.

### Fixed

- Tk's `canvas canvasy` returns floats; `Tcl_GetIntFromObj` is strict
  about that. Converting via `[expr {int(...)}]` in the helper procs
  before passing to the C-side `_click` / `_mouse`.
- Empty text nodes (e.g. `\n` inside `<pre>`, mapped to `""`
  internally by litehtml) are now rendered as a canvas text item
  with a real newline so the reserved line-height becomes visible.
- Extended `user_css` for `body` / `p` / `pre` with line-height and
  paragraph margins for browser-like vertical rhythm.

---

## [0.1.0] — Bug Fixes (2026-04-06)

### Fixed

- **`yview moveto`**: scrollbar drag now works correctly. New C++
  command `_scrollto PATH ABS_Y` sets `scroll_y` absolutely (instead
  of relatively like `_scroll`). `moveto` now calls `_scrollto`.
- **`configure`**: `on_link_click` and `yscrollcmd` are now loaded
  from the stored state at the start of the proc. `-command` and
  `-yscrollcommand` write changes back to `_widgets` (so `cget`
  returns correct values).
- **`import_css` local files**: `url` → `full_url` in
  `Tcl_OpenFileChannel` — relative CSS paths now resolve correctly.
- **`draw_image` scaling**: `-subsample 1 1` → `-to 0 0 w h` —
  images are scaled to the size requested in the HTML.

### Added

- `.gitignore`: `nogit/`, `lib/`, `vendor/litehtml-build/`,
  build artifacts
- `doc/en/windows-build.md` — Windows build guide in English
- `cget -canvas` — exposes internal canvas command path (e.g. for
  `pdf4tcl` `canvas` adapter usage)
- CSS cache in ContainerTk — prevents multiple HTTP fetches of the
  same stylesheet
- User-CSS for missing UA margins (`dd`, `dt`)
- `set_external_base_url` / `reset_base_url` — preserves user-set
  base URL even when litehtml tries to overwrite it
- `demos/demo-pdf.tcl` — 1-page PDF export via `$pdf canvas`
  (pdf4tcl) with `fontmap` for Unicode (DejaVuSans)

### Research

- `nogit/html-pdf-md-research.md` — analysis of HTML→PDF and HTML→MD
  options in Tcl/Tk
- `nogit/pdf-export-research.md` — ContainerPdf experiment (removed),
  canvas-based approach documented

---

## [0.1.0] — Initial Release (2026-04-03)

First release. Phase 1: Tk Canvas backend.

### Platform Support

- Linux: Tcl/Tk 8.6 and 9.0
- Windows: Tcl/Tk 8.6 and 9.0 (BAWT 3.2)

### Features

- HTML5 + CSS2/3 rendering via litehtml
- Tables with colspan / rowspan
- Vertical scrollbar (`-yscrollcommand`), mousewheel
- Link callbacks (`-command`, `-openurl`)
- Hover effects, cursor changes (hand, text, wait, move)
- Local images via Tk photo (`-file`)
- Dynamic images via `tcllitehtml::_setimage`
- Resize on `<Configure>`
- `tcllitehtml::_info` for doc_height, scroll_y, width, height

### Text Selection (added during 0.1.0)

- Text selection via mouse drag (overlay rectangle on canvas)
- `tcllitehtml::selection_start/stop/clear PATH`
- `Ctrl+A` copies all text, `Ctrl+C` copies selection
- PRIMARY selection (X11) + clipboard
- `tcllitehtml::_gettext PATH ?x1 y1 x2 y2?` returns text

### API

- `tcllitehtml::widget PATH ?options?`
- `.html load HTML`
- `.html load -file PATH`
- `.html yview moveto|scroll`
- `.html cget OPTION`
- `tcllitehtml::_setimage PATH URL PHOTO`

### Build

- Automatic litehtml patches (resolve_color recursion,
  font_description weight initialisation)
- `make` / `make tcl9` (Linux)
- `build-win.bat 86` / `build-win.bat 90` (Windows / BAWT)

### Tests

- 18 tests, all passing on Linux + Windows, Tcl 8.6 + 9.0

### Code-Review Fixes (2026-04-03)

- `configure`: `_init_linkclick` undefined → proper re-init
  implementation
- `configure`: `-yscrollcommand /* TODO */` (invalid Tcl) → fixed
- widget: `-openurl` option not parsed → added to option parser
- widget: `-fontsize` option not parsed → added to option parser
- widget: missing `package provide` → added at end of widget-0.1.tm
- Makefile: `test9` target duplicated → deduplicated

### Bug Fixes During Development

| # | Issue |
|---|-------|
| 3 | False/True macro conflict (litehtml before Tk include) |
| 6 | `resolve_color` recursion crash (Linux) |
| 12 | Double `scroll_y` subtraction in draw methods |
| 14 | `resolve_color` infinite recursion (Windows) |
| 15 | `font_description::hash()` SIGSEGV — uninitialised weight (Windows) |
| 16 | `Tcl_InitStubs` version conflict with Tcl 9.0 |

Full bug list: `nogit/start.md`.

### Known Limitations (carried into Phase 2)

- `background-repeat` not implemented
- Cairo backend not yet available
- Multi-page PDF export not supported
- Forms not supported
- Fragment links (`#id` jumps) not supported
