#!/usr/bin/env python3
# patch-litehtml.py -- web_color.cpp patchen
# Aufruf: python patches\patch-litehtml.py

import sys, os

target = os.path.join("vendor", "litehtml", "src", "web_color.cpp")

if not os.path.exists(target):
    print("FEHLER: {} nicht gefunden".format(target))
    sys.exit(1)

with open(target, encoding="utf-8") as f:
    src = f.read()

if "resolve_color() causes recursion" in src:
    print("OK: Patch bereits angewendet")
    sys.exit(0)

old = "\tif (container)\n\t\treturn container->resolve_color(name);\n"
new = "\t// Removed: resolve_color() causes recursion crash (tcllitehtml patch)\n\treturn \"\";\n"

if old not in src:
    print("FEHLER: Pattern nicht gefunden -- falscher litehtml Commit?")
    sys.exit(1)

src = src.replace(old, new)
with open(target, "w", encoding="utf-8") as f:
    f.write(src)
print("OK: {} gepatcht".format(target))
