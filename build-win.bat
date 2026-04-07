@echo off
REM build-win.bat -- tcllitehtml bauen unter Windows/BAWT
REM Aufruf: build-win.bat [86|90]
REM Default: Tcl 8.6

set TCL_VER=%1
if "%TCL_VER%"=="" set TCL_VER=86

if "%TCL_VER%"=="86" (
    set BAWT=C:\Bawt\Bawt86
    set STUBLIB_TCL=tclstub86
    set STUBLIB_TK=tkstub86
) else (
    set BAWT=C:\Bawt\Bawt903
    set STUBLIB_TCL=:libtclstub.a
    set STUBLIB_TK=:libtkstub.a
)

REM BAWT 3.2.0 Pfadstruktur
set GCCBIN=%BAWT%\Tools\gcc14.2.0_x86_64-w64-mingw32\mingw64\bin
set CMAKE=%BAWT%\Windows\x64\Development\opt\CMake\bin\cmake.exe
set MAKE=%GCCBIN%\mingw32-make.exe
set TCLROOT=%BAWT%\Windows\x64\Development\opt\Tcl
set TKROOT=%BAWT%\Windows\x64\Development\opt\Tcl
set PATH=%GCCBIN%;%PATH%

echo.
echo === BAWT: %BAWT%
echo === Tcl:  %TCLROOT%
echo === GCC:  %GCCBIN%
echo.

REM Prüfen
if not exist "%GCCBIN%\gcc.exe" (
    echo FEHLER: gcc nicht gefunden: %GCCBIN%\gcc.exe
    exit /b 1
)
if not exist "vendor\litehtml\CMakeLists.txt" (
    echo FEHLER: vendor\litehtml fehlt.
    echo Bitte ausfuehren: git clone --depth=1 https://github.com/litehtml/litehtml vendor\litehtml
    exit /b 1
)

echo === 0. litehtml patchen ===
python patches\patch-litehtml.py
if errorlevel 1 goto :error
python patches\patch-font-description.py
if errorlevel 1 goto :error

echo === 1. litehtml bauen ===
if not exist vendor\litehtml-build mkdir vendor\litehtml-build
cd vendor\litehtml-build
"%CMAKE%" -G "MinGW Makefiles" ^
    -DCMAKE_BUILD_TYPE=Release ^
    -DBUILD_SHARED_LIBS=OFF ^
    -DLITEHTML_BUILD_TESTING=OFF ^
    -DCMAKE_CXX_FLAGS="-fPIC" ^
    -DCMAKE_C_FLAGS="-fPIC" ^
    ..\litehtml
if errorlevel 1 goto :error
"%MAKE%" litehtml
if errorlevel 1 goto :error
cd ..\..
echo OK: vendor\litehtml-build\liblitehtml.a

echo.
echo === 2. libtcllitehtml.dll bauen ===
if not exist lib mkdir lib

"%GCCBIN%\g++.exe" ^
    -shared -fPIC -Wall -g -O0 -std=c++17 ^
    -I"%TCLROOT%\include" -I"%TKROOT%\include" ^
    -Isrc ^
    -Ivendor\litehtml\include ^
    -DUSE_TCL_STUBS -DUSE_TK_STUBS -DWIN32 ^
    -o lib\libtcllitehtml.dll ^
    src\tcllitehtml.cpp src\container_tk.cpp ^
    vendor\litehtml-build\liblitehtml.a ^
    vendor\litehtml-build\src\gumbo\libgumbo.a ^
    -L"%TCLROOT%\lib" ^
    -l%STUBLIB_TCL% -l%STUBLIB_TK% ^
    -lm -lws2_32 ^
    -Wl,--stack,16777216

if errorlevel 1 goto :error

echo.
echo === Build erfolgreich ===
dir lib\libtcllitehtml.dll
goto :end

:error
echo.
echo === FEHLER beim Build ===
exit /b 1

:end
echo.
echo Test starten:
echo   %TCLROOT%\bin\wish.exe demos\demo-basic.tcl
