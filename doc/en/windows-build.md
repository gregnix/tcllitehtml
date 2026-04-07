# tcllitehtml — Windows Build Setup

**Tested:** Windows 10/11, BAWT 3.2, Tcl 8.6 + 9.0

---

## Prerequisites

| Tool | Download | Path after install |
|------|----------|--------------------|
| BAWT 3.2 (Tcl 8.6) | https://www.bawt.tcl3d.org/ | `C:\Bawt\Bawt86\` |
| BAWT 3.2 (Tcl 9.0) | https://www.bawt.tcl3d.org/ | `C:\Bawt\Bawt903\` |
| Git | https://git-scm.com/ or `winget install Git.Git` | in PATH |
| Python 3 | https://python.org/ or `winget install Python.Python.3` | in PATH |

---

## Step by Step (cmd.exe)

### 1. Create project directory

```cmd
mkdir C:\build
cd C:\build
```

Unzip the archive → results in:
```
C:\build\tcllitehtml-0.1.0\tcllitehtml-0.1.0\
  src\
  tcl\
  demos\
  tests\
  patches\
  build-win.bat    ← build script
  test-win.bat     ← test script
  vendor\          ← initially empty
  lib\             ← initially empty
```

**Note:** The double directory name (`tcllitehtml-0.1.0\tcllitehtml-0.1.0\`) is
a ZIP artifact — normal, does not affect the build.

### 2. Clone litehtml

```cmd
cd C:\build\tcllitehtml-0.1.0\tcllitehtml-0.1.0
git clone --depth=1 https://github.com/litehtml/litehtml vendor\litehtml
```

### 3. Build

```cmd
build-win.bat
```

What `build-win.bat` does:
```
Step 0: patch litehtml (patch-litehtml.py + patch-font-description.py)
Step 1: build litehtml with cmake → vendor\litehtml-build\liblitehtml.a
Step 2: build libtcllitehtml.dll → lib\libtcllitehtml.dll
```

For Tcl 9.0:
```cmd
build-win.bat 90
```

### 4. Test

```cmd
test-win.bat
```

Expected: `Total 18  Passed 18  Failed 0`

### 5. Run demos

```cmd
set PATH=C:\Bawt\Bawt86\Windows\x64\Development\opt\Tcl\bin;%PATH%
wish demos\demo-basic.tcl
wish demos\demo-browser.tcl
```

---

## BAWT Paths

```
BAWT 8.6:  C:\Bawt\Bawt86\
  gcc:     ...\Tools\gcc14.2.0_x86_64-w64-mingw32\mingw64\bin\
  cmake:   ...\Windows\x64\Development\opt\CMake\bin\
  Tcl:     ...\Windows\x64\Development\opt\Tcl\
  wish:    ...\Windows\x64\Development\opt\Tcl\bin\wish.exe

BAWT 9.0:  C:\Bawt\Bawt903\
  Stubs:   libtclstub.a / libtkstub.a (MinGW format, NOT .lib!)
```

**Tcl 8.6 vs 9.0 stubs:**
```
Tcl 8.6: MSVC-built → tclstub86.lib  (gcc can load .lib)
Tcl 9.0: MinGW-built → libtclstub.a  (gcc needs -l:libtclstub.a)
```

---

## Rebuilding after code changes

```cmd
:: Only src/ changed:
del lib\libtcllitehtml.dll
build-win.bat

:: litehtml sources changed:
rmdir /s /q vendor\litehtml-build
del lib\libtcllitehtml.dll
build-win.bat
```

---

## Known Issues

| Problem | Cause | Fix |
|---------|-------|-----|
| SIGSEGV in `font_description::hash()` | uninitialized `int weight` | `patch-font-description.py` (auto) |
| Infinite recursion in `resolve_color()` | litehtml bug | `patch-litehtml.py` (auto) |
| Umlauts wrong | Tcl reads .tcl as cp1252 | use HTML entities instead |
| Tests produce no output | wish stdout not visible in cmd | redirect: `test-win.bat > out.txt 2>&1` |

Both patches are applied **automatically** by `build-win.bat`.

---

## GDB Debugging

```cmd
winget install BrechtSanders.WinLibs.POSIX.MSVCRT

set WISH=C:\Bawt\Bawt86\Windows\x64\Development\opt\Tcl\bin\wish.exe
gdb %WISH%
(gdb) set args c:/build/test.tcl
(gdb) run
(gdb) bt
```
