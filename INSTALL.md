# tcllitehtml — Installation

Once the build is done (`make` on Linux, `build-win.bat` on Windows),
`tcllitehtml` is **not** automatically installed system-wide. The
`pkgIndex.tcl` shipped under `tcl/tcllitehtml/` works for in-tree use
from the repo. For everyday use it is more convenient to install into
a user-local Tcl module directory.

This guide describes the flat-install layout: one directory per
package, all artifacts (`.tm`, `.so` / `.dll`, `pkgIndex.tcl`)
together.

---

## Linux

### One-time setup

```bash
# 1. Build for both Tcl versions you use
cd /path/to/tcllitehtml
make litehtml          # fetch and patch vendor/litehtml (one time)
make                   # Tcl 8.6  -> lib/libtcllitehtml.so
make tcl9              # Tcl 9.0  -> lib/libtcllitehtml9.so

# 2. Create the install directory
mkdir -p ~/lib/tcltk/tcllitehtml

# 3. Copy the Tcl module and the flat-install pkgIndex.tcl
cp tcl/tcllitehtml/widget-0.1.tm ~/lib/tcltk/tcllitehtml/
cp pkgIndex-flat.tcl ~/lib/tcltk/tcllitehtml/pkgIndex.tcl
#   (or use the file from install-linux.sh — see below)

# 4. Copy the libraries
[ -f lib/libtcllitehtml.so  ] && cp lib/libtcllitehtml.so  ~/lib/tcltk/tcllitehtml/
[ -f lib/libtcllitehtml9.so ] && cp lib/libtcllitehtml9.so ~/lib/tcltk/tcllitehtml/

# 5. Tell Tcl where to look (in ~/.bashrc)
echo 'export TCLLIBPATH="$HOME/lib/tcltk"' >> ~/.bashrc
source ~/.bashrc
```

### Verify

```bash
tclsh   <<< 'package require tcllitehtml; puts ok-86'
tclsh90 <<< 'package require tcllitehtml; puts ok-90'
```

Expected output: `ok-86` or `ok-90`.

### Mini install script

Drop this as `install-linux.sh` next to the Makefile:

```bash
#!/usr/bin/env bash
set -e
PREFIX="${PREFIX:-$HOME/lib/tcltk}"
DEST="$PREFIX/tcllitehtml"
mkdir -p "$DEST"
cp tcl/tcllitehtml/widget-0.1.tm "$DEST/"
cp pkgIndex-flat.tcl              "$DEST/pkgIndex.tcl"
[ -f lib/libtcllitehtml.so  ] && cp lib/libtcllitehtml.so  "$DEST/"
[ -f lib/libtcllitehtml9.so ] && cp lib/libtcllitehtml9.so "$DEST/"
echo "Installed to $DEST"
```

---

## Windows (BAWT)

### Option A — BAWT-tree install (simplest)

The BAWT installation contains the MinGW runtime DLLs, so no extra
DLLs need to be copied. Tcl finds the package automatically without
`TCLLIBPATH`.

```cmd
:: Build first
build-win.bat 86

:: Install into the BAWT lib directory
set BAWT=C:\BAWT\Bawt86
mkdir "%BAWT%\Windows\x64\Development\opt\Tcl\lib\tcllitehtml"
copy tcl\tcllitehtml\widget-0.1.tm  "%BAWT%\Windows\x64\Development\opt\Tcl\lib\tcllitehtml\"
copy pkgIndex-flat.tcl              "%BAWT%\Windows\x64\Development\opt\Tcl\lib\tcllitehtml\pkgIndex.tcl"
copy lib\libtcllitehtml.dll         "%BAWT%\Windows\x64\Development\opt\Tcl\lib\tcllitehtml\"
```

Repeat with `BAWT=C:\BAWT\Bawt903` for Tcl 9.0 if you use both.

### Option B — User-local install

Like the Linux flat layout, plus the three MinGW runtime DLLs:

```cmd
set PREFIX=%USERPROFILE%\lib\tcltk
mkdir "%PREFIX%\tcllitehtml"

copy tcl\tcllitehtml\widget-0.1.tm  "%PREFIX%\tcllitehtml\"
copy pkgIndex-flat.tcl              "%PREFIX%\tcllitehtml\pkgIndex.tcl"
copy lib\libtcllitehtml.dll         "%PREFIX%\tcllitehtml\"

:: MinGW runtime DLLs (libtcllitehtml.dll depends on these)
set GCCBIN=C:\BAWT\Bawt86\Tools\gcc14.2.0_x86_64-w64-mingw32\mingw64\bin
copy "%GCCBIN%\libstdc++-6.dll"   "%PREFIX%\tcllitehtml\"
copy "%GCCBIN%\libgcc_s_seh-1.dll" "%PREFIX%\tcllitehtml\"
copy "%GCCBIN%\libwinpthread-1.dll" "%PREFIX%\tcllitehtml\"

:: TCLLIBPATH permanently (need new cmd afterwards)
setx TCLLIBPATH "%USERPROFILE%\lib\tcltk"
```

### Verify

```cmd
"C:\BAWT\Bawt86\Windows\x64\Development\opt\Tcl\bin\tclsh.exe" -c "package require tcllitehtml; puts ok"
```

---

## Flat-install pkgIndex.tcl

The `pkgIndex.tcl` that ships in `tcl/tcllitehtml/` uses relative paths
(`../../lib/`) which work for the repo layout but not for a flat
install. The flat variant lives in the repo root as `pkgIndex-flat.tcl`
and looks like:

```tcl
package ifneeded tcllitehtml 0.1.0 [list apply {{dir} {
    if {$::tcl_platform(platform) eq "windows"} {
        # Pre-load MinGW runtime DLLs if present (so the loader
        # finds them next to libtcllitehtml.dll)
        set _oldpath $::env(PATH)
        set ::env(PATH) "$dir;$_oldpath"
        foreach _dep {
            libwinpthread-1.dll
            libgcc_s_seh-1.dll
            libstdc++-6.dll
        } {
            set _p [file join $dir $_dep]
            if {[file exists $_p]} { catch {load $_p} }
        }
        set _lib [file join $dir libtcllitehtml.dll]
    } elseif {[package vsatisfies [package provide Tcl] 9.0-]} {
        set _lib9 [file join $dir libtcllitehtml9.so]
        set _lib  [file join $dir libtcllitehtml.so]
        if {[file exists $_lib9]} { set _lib $_lib9 }
    } else {
        set _lib [file join $dir libtcllitehtml.so]
    }
    if {[file exists $_lib]} {
        load $_lib
    } else {
        error "tcllitehtml: $_lib not found"
    }
    if {$::tcl_platform(platform) eq "windows"} {
        set ::env(PATH) $_oldpath
    }
    source [file join $dir widget-0.1.tm]
}} $dir]
```

The original `tcl/tcllitehtml/pkgIndex.tcl` remains in place for
in-repo development (works straight out of `make`).

---

## Updating after code changes

```bash
# Linux
cd /path/to/tcllitehtml
make && make tcl9      # rebuild
cp lib/libtcllitehtml*.so ~/lib/tcltk/tcllitehtml/
cp tcl/tcllitehtml/widget-0.1.tm ~/lib/tcltk/tcllitehtml/
```

```cmd
:: Windows
cd C:\path\to\tcllitehtml
build-win.bat 86
copy lib\libtcllitehtml.dll  "%PREFIX%\tcllitehtml\"  :: or BAWT dir
copy tcl\tcllitehtml\widget-0.1.tm  "%PREFIX%\tcllitehtml\"
```

---

## Endstate

After install, both Linux and Windows have the same layout:

```
~/lib/tcltk/tcllitehtml/     (Linux)
  or
%USERPROFILE%\lib\tcltk\tcllitehtml\   (Windows)

├── pkgIndex.tcl              (flat variant)
├── widget-0.1.tm
├── libtcllitehtml.so         (Linux, Tcl 8.6)
├── libtcllitehtml9.so        (Linux, Tcl 9.0)
└── libtcllitehtml.dll        (Windows)
    libstdc++-6.dll
    libgcc_s_seh-1.dll
    libwinpthread-1.dll
```

`TCLLIBPATH` set to the parent (`~/lib/tcltk` or
`%USERPROFILE%\lib\tcltk`).

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `package require tcllitehtml` → not found | TCLLIBPATH not set | set it; restart shell |
| `this extension is compiled for Tcl 9.0` | wrong tclsh / wish | use `tclsh90` / `wish90` with the 9.0 build |
| Windows: `couldn't load file libtcllitehtml.dll: not a valid Win32 application` | MinGW runtime DLLs missing | copy `libstdc++-6.dll`, `libgcc_s_seh-1.dll`, `libwinpthread-1.dll` next to the DLL |
| Linux: `undefined symbol: Tcl_InitStubs` | wrong Tcl headers at build time | `make clean && make` against the correct `tclConfig.sh` |
