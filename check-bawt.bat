@echo off
REM check-bawt.bat -- BAWT Pfade prüfen

set BAWT86=C:\Bawt\Bawt86
set BAWT90=C:\Bawt\Bawt903

echo === Prüfe BAWT 8.6 ===
if exist "%BAWT86%\Tools\gcc14.2.0_x86_64-w64-mingw32\mingw64\bin\gcc.exe" (
    echo OK: gcc gefunden
) else (
    echo SUCHE gcc...
    dir "%BAWT86%\Tools\" 2>nul | findstr /i "gcc"
)

if exist "%BAWT86%\Windows\x64\Development\opt\CMake\bin\cmake.exe" (
    echo OK: cmake gefunden
) else (
    echo SUCHE cmake...
    dir "%BAWT86%\Windows\x64\Development\opt\" 2>nul
)

if exist "%BAWT86%\Windows\x64\Development\opt\Tcl\bin\tclsh86.exe" (
    echo OK: tclsh86 gefunden
) else if exist "%BAWT86%\Windows\x64\Development\opt\Tcl\bin\tclsh.exe" (
    echo OK: tclsh gefunden
) else (
    echo SUCHE tclsh...
    dir "%BAWT86%\Windows\x64\Development\opt\Tcl\bin\" 2>nul
)

if exist "%BAWT86%\Windows\x64\Development\opt\Tcl\lib\tclstub86.lib" (
    echo OK: tclstub86.lib gefunden
) else (
    echo SUCHE stubs...
    dir "%BAWT86%\Windows\x64\Development\opt\Tcl\lib\tcl*.lib" 2>nul
    dir "%BAWT86%\Windows\x64\Development\opt\Tcl\lib\tcl*.a" 2>nul
)

echo.
echo === Prüfe BAWT 9.0 ===
if exist "%BAWT90%\Windows\x64\Development\opt\Tcl\lib\libtclstub.a" (
    echo OK: libtclstub.a gefunden
) else (
    echo SUCHE stubs...
    dir "%BAWT90%\Windows\x64\Development\opt\Tcl\lib\*stub*" 2>nul
)

echo.
echo === Fertig ===
