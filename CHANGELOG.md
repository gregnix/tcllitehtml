
## [0.1.0] — Bug Fixes (2026-04-06)

### Fixed

- **yview moveto**: Scrollbar-Drag funktioniert jetzt korrekt.
  Neues C++-Kommando `_scrollto PATH ABS_Y` setzt `scroll_y` absolut
  (statt relativ wie `_scroll`). `moveto` ruft jetzt `_scrollto` auf.
- **configure**: `on_link_click` und `yscrollcmd` werden jetzt am Anfang
  aus dem gespeicherten State geladen. `-command` und `-yscrollcommand`
  schreiben Änderungen auch in `_widgets` zurück (cget liefert korrekte Werte).
- **import_css lokale Dateien**: `url` → `full_url` in
  `Tcl_OpenFileChannel` — relative CSS-Pfade werden korrekt aufgelöst.
- **draw_image Skalierung**: `-subsample 1 1` → `-to 0 0 w h` —
  Bilder werden auf die vom HTML vorgegebene Größe skaliert.

### Added

- `.gitignore`: `nogit/`, `lib/`, `vendor/litehtml-build/`, build-Artefakte
- `doc/en/windows-build.md`: Windows Build-Anleitung (englisch)

# Changelog — tcllitehtml

## 0.1.0 (2026-04-03)

First release. Phase 1: Tk-Canvas backend.

### Platform Support
- Linux: Tcl/Tk 8.6 and 9.0
- Windows: Tcl/Tk 8.6 and 9.0 (BAWT 3.2)

### Features
- HTML5 + CSS2/3 rendering via litehtml
- Tables with colspan/rowspan
- Vertical scrollbar (-yscrollcommand), mousewheel
- Link callbacks (-command, -openurl)
- Hover effects, cursor changes (hand, text, wait, move)
- Local images via Tk photo (-file)
- Dynamic images via `tcllitehtml::_setimage`
- Resize on `<Configure>`
- `tcllitehtml::_info` for doc_height, scroll_y, width, height

### API
- `tcllitehtml::widget PATH ?options?`
- `.html load HTML`
- `.html load -file PATH`
- `.html yview moveto|scroll`
- `.html cget OPTION`
- `tcllitehtml::_setimage PATH URL PHOTO`

### Build
- Automatic litehtml patches (resolve_color recursion, font_description)
- `make` / `make TCL_VER=9.0` (Linux)
- `build-win.bat` / `build-win.bat 90` (Windows/BAWT)

### Tests
- 18 tests, all passing (Linux + Windows, Tcl 8.6 + 9.0)

### Known Limitations
- `background-repeat` not implemented (Phase 2)
- No Selection/Clipboard (Phase 3)
- No Forms (Phase 3)
- No PDF Export (Phase 3)
- Cairo backend not yet available (Phase 2)

### Selection (2026-04-04)
- Text selection via mouse drag (overlay rectangle on canvas)
- `tcllitehtml::selection_start/stop/clear PATH`
- `Ctrl+A` copies all text, `Ctrl+C` copies selection
- PRIMARY selection (X11) + clipboard
- `tcllitehtml::_gettext PATH ?x1 y1 x2 y2?` returns text
- Tested: Linux + Windows

### Fixes after Code Review (2026-04-03)
- configure: _init_linkclick undefined → proper re-init implementation
- configure: -yscrollcommand `/* TODO */` (invalid Tcl) → fixed
- widget: -openurl option not parsed → added to option parser
- widget: -fontsize option not parsed → added to option parser
- widget: missing `package provide` → added at end of widget-0.1.tm
- Makefile: test9 target duplicated → deduplicated

### Bug Fixes (during development)
- #3  False/True macro conflict (litehtml before Tk include)
- #6  resolve_color recursion crash (Linux)
- #12 Double scroll_y subtraction in draw methods
- #14 resolve_color infinite recursion (Windows)
- #15 font_description::hash() SIGSEGV — uninitialized weight (Windows)
- #16 Tcl_InitStubs version conflict with Tcl 9.0

Full bug list: `nogit/start.md`

## [0.1.0] - Ergänzungen nach Release

### Added
- `cget -canvas` — Zugriff auf internen Canvas-Widget-Path
- CSS-Cache in ContainerTk — verhindert mehrfaches HTTP-Laden
- User-CSS für fehlende UA-Margins (`dd`, `dt`)
- `set_external_base_url` / `reset_base_url` — verhindert dass litehtml
  externe baseurl überschreibt
- `demos/demo-pdf.tcl` — 1-seitiger PDF Export via `$pdf canvas` (pdf4tcl)
  mit fontmap für Unicode (DejaVuSans)

### Research
- nogit/html-pdf-md-research.md: Analyse HTML→PDF und HTML→MD in Tcl/Tk
- nogit/pdf-export-research.md: ContainerPdf (entfernt), canvas-Ansatz dokumentiert
