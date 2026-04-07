#!/usr/bin/env python3
# patch-font-description.py -- font_description.h patchen
# Behebt: uninitialisiertes 'weight' + hash() crash auf Windows

import sys, os

target = os.path.join("vendor", "litehtml", "include", "litehtml", "font_description.h")

if not os.path.exists(target):
    print("FEHLER: {} nicht gefunden".format(target))
    sys.exit(1)

with open(target, encoding="utf-8") as f:
    src = f.read()

if "tcllitehtml patch" in src:
    print("OK: Patch bereits angewendet")
    sys.exit(0)

# 1. weight ohne Initializer → weight = 400
old1 = "\t\tint\t\t\t\t\t\tweight;\t\t\t\t// Font weight."
new1 = "\t\tint\t\t\t\t\t\tweight = 400;\t\t\t// Font weight. (tcllitehtml patch: added default)"
if old1 in src:
    src = src.replace(old1, new1)
    print("OK: weight = 400 gesetzt")
else:
    print("WARN: weight-Pattern nicht gefunden")

# 2. hash() vereinfachen - nur simple Typen, kein css_length/web_color
old2 = """\t\tstd::string\thash() const
\t\t{
\t\t\tstd::string out;
\t\t\tout += family;
\t\t\tout += \":sz=\" + std::to_string(size);
\t\t\tout += \":st=\" + std::to_string(style);
\t\t\tout += \":w=\" + std::to_string(weight);
\t\t\tout += \":dl=\" + std::to_string(decoration_line);
\t\t\tout += \":dt=\" + decoration_thickness.to_string();
\t\t\tout += \":ds=\" + std::to_string(decoration_style);
\t\t\tout += \":dc=\" + decoration_color.to_string();
\t\t\tout += \":ephs=\" + emphasis_style;
\t\t\tout += \":ephc=\" + emphasis_color.to_string();
\t\t\tout += \":ephp=\" + std::to_string(emphasis_position);

\t\t\treturn out;
\t\t}"""

new2 = """\t\tstd::string\thash() const
\t\t{
\t\t\t// tcllitehtml patch: simplified hash - avoid css_length/web_color on Windows
\t\t\tstd::string out;
\t\t\tout.reserve(64);
\t\t\tout += family;
\t\t\tout += \":sz=\" + std::to_string((int)size);
\t\t\tout += \":st=\" + std::to_string((int)style);
\t\t\tout += \":w=\" + std::to_string(weight);
\t\t\tout += \":dl=\" + std::to_string(decoration_line);
\t\t\tout += \":ds=\" + std::to_string((int)decoration_style);
\t\t\tout += \":ep=\" + std::to_string(emphasis_position);
\t\t\treturn out;
\t\t}"""

if old2 in src:
    src = src.replace(old2, new2)
    print("OK: hash() vereinfacht")
else:
    print("WARN: hash()-Pattern nicht gefunden - versuche Alternative")
    # Kürzere Variante
    idx = src.find("std::string\thash() const")
    if idx >= 0:
        end = src.find("\t\t}", idx) + 3
        print("  Gefunden bei:", idx, "bis", end)
        print("  Alt:", repr(src[idx:end][:100]))

with open(target, "w", encoding="utf-8") as f:
    f.write(src)
print("OK: {} gepatcht".format(target))
