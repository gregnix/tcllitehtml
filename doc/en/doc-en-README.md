# tcllitehtml Documentation

## For Users

| File | Content |
|------|---------|
| [api-reference.md](api-reference.md) | All options, commands, callbacks, limitations |
| [integration.md](integration.md) | Embedding in applications (mdhelp4, man-viewer) |
| [performance.md](performance.md) | Measurements and the Stufe-1+2 performance refactor |
| [windows-build.md](windows-build.md) | Windows build with BAWT |

Top-level (in the repo root):

| File | Content |
|------|---------|
| [../../README.md](../../README.md) | Quick start, options, status |
| [../../INSTALL.md](../../INSTALL.md) | Installation into user-local Tcl lib paths |
| [../../CHANGELOG.md](../../CHANGELOG.md) | Release history |

## For Developers

| File | Content |
|------|---------|
| [architecture.md](architecture.md) | Architecture, coordinate system, re-render triggers |
| [performance.md](performance.md) | Stufe 1+2 changes in detail, trade-offs, what's next |

### Developer notes (German, internal — `nogit/docs/de/`)

These are not shipped in the repo but exist in the developer's
working tree:

| Topic | German notes file |
|-------|---|
| Tk Canvas reference (items, PostScript, PDF export, zoom) | `nogit/docs/de/canvas.md` |
| Canvas internals specific to tcllitehtml | `nogit/docs/de/canvas-tcllitehtml.md` |
| Tk Canvas source code map (Tcl/Tk 8.6.17) | `nogit/docs/de/tk-canvas-sourcemap.md` |
| Tk C API: `Tk_TextWidth`, `Tk_GetFont` etc. | `nogit/docs/de/tk-c-api.md` |
| Building C/C++ Tcl/Tk extensions | `nogit/docs/de/tcl-extension-howto.md` |
| Scrolling internals (pre-Stufe-2) | `nogit/docs/de/scrolling.md` |
| Error handling from C++ | `nogit/docs/de/error-handling.md` |
| litehtml `document_container` interface | `nogit/docs/de/litehtml-reference.md` |
| C-Tcl-Bridge pitfalls (Float vs. Int, ...) | `nogit/docs/de/c-tcl-bridge.md` |

Translations are case-by-case as topics become relevant for end
users.
