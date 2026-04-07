@echo off
REM test-win.bat -- Tests unter Windows
set TCLBIN=C:\Bawt\Bawt86\Windows\x64\Development\opt\Tcl\bin
set PATH=%TCLBIN%;%PATH%

echo === tcllitehtml Tests ===
%TCLBIN%\wish.exe tests\test-basic.tcl > test-results.txt 2>&1
type test-results.txt
echo ===
