@echo off
REM install-win.bat -- Kopiert tcllitehtml ins user-lokale Tcl-Lib-Verzeichnis.
REM
REM Voraussetzung: vorher 'build-win.bat 86' oder 'build-win.bat 90'.
REM Aufruf aus dem Repo-Wurzelverzeichnis: install-win.bat
REM Optional: install-win.bat 86  ODER  install-win.bat 90
REM           (steuert, welche MinGW-Runtime-DLLs mitkopiert werden)

setlocal

set TCL_VER=%1
if "%TCL_VER%"=="" set TCL_VER=86

if "%TCL_VER%"=="86" (
    set BAWT=C:\BAWT\Bawt86
) else (
    set BAWT=C:\BAWT\Bawt903
)
set GCCBIN=%BAWT%\Tools\gcc14.2.0_x86_64-w64-mingw32\mingw64\bin

set PREFIX=%USERPROFILE%\lib\tcltk
set DEST=%PREFIX%\tcllitehtml

if not exist "%DEST%" mkdir "%DEST%"

REM Tcl-Modul
copy tcl\tcllitehtml\widget-0.1.tm "%DEST%\" >nul
if errorlevel 1 goto :error

REM Angepasste pkgIndex.tcl (Option B). Erwartet wird die Datei neben dieser .bat.
if exist "%~dp0tcllitehtml-pkgIndex-flat-b.tcl" (
    copy "%~dp0tcllitehtml-pkgIndex-flat-b.tcl" "%DEST%\pkgIndex.tcl" >nul
) else (
    echo WARNUNG: pkgIndex-Adapter nicht gefunden, nutze Original.
    echo          Relative Pfade werden brechen!
    copy tcl\tcllitehtml\pkgIndex.tcl "%DEST%\" >nul
)

REM tcllitehtml.dll
if not exist lib\libtcllitehtml.dll (
    echo FEHLER: lib\libtcllitehtml.dll fehlt. Bitte vorher build-win.bat %TCL_VER% ausfuehren.
    exit /b 1
)
copy lib\libtcllitehtml.dll "%DEST%\" >nul

REM MinGW-Runtime-DLLs mitkopieren
if exist "%GCCBIN%\libstdc++-6.dll"   copy "%GCCBIN%\libstdc++-6.dll"   "%DEST%\" >nul
if exist "%GCCBIN%\libgcc_s_seh-1.dll" copy "%GCCBIN%\libgcc_s_seh-1.dll" "%DEST%\" >nul
if exist "%GCCBIN%\libwinpthread-1.dll" copy "%GCCBIN%\libwinpthread-1.dll" "%DEST%\" >nul

echo.
echo Installation in %DEST% abgeschlossen.
echo.
echo Damit Tcl das Paket findet, einmalig in Umgebungsvariablen:
echo   set TCLLIBPATH=%PREFIX%
echo (oder dauerhaft via Systemsteuerung / setx)
echo.
echo Verifizieren:
echo   "%BAWT%\Windows\x64\Development\opt\Tcl\bin\tclsh.exe" -c "package require tcllitehtml; puts [package present tcllitehtml]"
exit /b 0

:error
echo.
echo FEHLER beim Kopieren.
exit /b 1
