@echo off
REM apply_patch.bat -- litehtml web_color.cpp patchen
REM Aufruf aus: tcllitehtml-0.1.0\

set WEB_COLOR=vendor\litehtml\src\web_color.cpp

echo Patche %WEB_COLOR%...

REM Python-Script zum Patchen (zuverlässiger als patch.exe)
python -c "
import sys
f = open(r'vendor\litehtml\src\web_color.cpp', encoding='utf-8')
src = f.read()
f.close()

old = '''	if (container)
		return container->resolve_color(name);
'''
new = '''	// Removed: resolve_color() causes recursion crash (tcllitehtml patch)
'''

if old in src:
    src = src.replace(old, new)
    f = open(r'vendor\litehtml\src\web_color.cpp', 'w', encoding='utf-8')
    f.write(src)
    f.close()
    print('OK: web_color.cpp gepatcht')
elif 'resolve_color() causes recursion' in src:
    print('OK: Patch bereits angewendet')
else:
    print('FEHLER: Pattern nicht gefunden')
    sys.exit(1)
"
