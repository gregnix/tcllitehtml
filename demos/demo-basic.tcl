#!/usr/bin/env wish
set _dir [file normalize [file dirname [info script]]]

# Option A: package require (wenn tcl::tm::path gesetzt)
# tcl::tm::path add [file join $_dir ../tcl]
# package require tcllitehtml

# Option B: direkt sourcen (immer funktioniert)
# Plattform-unabhaengig: .so (Linux) oder .dll (Windows)
# Richtige .so je nach Tcl-Version (mit Fallback)
if {$::tcl_platform(platform) eq "windows"} {
    set _lib [file join $_dir ../lib/libtcllitehtml.dll]
} elseif {[package vsatisfies [package provide Tcl] 9.0-]} {
    set _lib9 [file join $_dir ../lib/libtcllitehtml9.so]
    set _lib  [file join $_dir ../lib/libtcllitehtml.so]
    if {[file exists $_lib9]} { set _lib $_lib9 }
} else {
    set _lib [file join $_dir ../lib/libtcllitehtml.so]
}
load $_lib
source [file join $_dir ../tcl/tcllitehtml/widget-0.1.tm]

wm title . "tcllitehtml Demo"
wm geometry . 820x620
bind . <Escape> { destroy . }

frame .f
pack .f -fill both -expand 1

scrollbar .f.sb -orient vertical -command {.f.html yview}
tcllitehtml::widget .f.html \
    -width 780 \
    -background white \
    -yscrollcommand {.f.sb set} \
    -command {apply {{url} { puts "Link: $url" }}}

pack .f.sb   -side right -fill y
pack .f.html -side left  -fill both -expand 1

.f.html load {
<html><head>
<style>
  body { font-family: Sans; font-size: 14px; margin: 20px; }
  h1   { color: #2040a0; border-bottom: 2px solid #2040a0; }
  h2   { color: #4060c0; }
  p    { line-height: 1.6; }
  a    { color: #2060c0; }
  table { border-collapse: collapse; width: 100%; margin: 12px 0; }
  th { background: #2040a0; color: white; padding: 6px 10px; }
  td { border: 1px solid #ccc; padding: 5px 10px; }
  tr:nth-child(even) { background: #f0f0f8; }
  li { margin: 4px 0; }
  code { background: #eef; padding: 2px 4px; font-family: Monospace; }
</style></head><body>
<h1>tcllitehtml 0.1.0</h1>
<p>HTML5 + CSS2/3 Widget. <a href="https://github.com/litehtml/litehtml">litehtml auf GitHub</a></p>
<h2>Unterst&uuml;tzte Elemente</h2>
<table>
  <tr><th>Element</th><th>Status</th></tr>
  <tr><td>h1 - h6</td><td>OK</td></tr>
  <tr><td>p, b, i, code</td><td>OK</td></tr>
  <tr><td>Tabellen (colspan/rowspan)</td><td>OK</td></tr>
  <tr><td>Listen ul/ol</td><td>OK</td></tr>
  <tr><td>Links a href</td><td>OK (Callback)</td></tr>
  <tr><td>Bilder</td><td>OK</td></tr>
  <tr><td>CSS Gradienten</td><td>Phase 2</td></tr>
</table>
<h2>Anwendungsfaelle</h2>
<ul>
  <li><a href="mdhelp4">mdhelp4</a> - Hilfeseiten</li>
  <li><a href="man-viewer">man-viewer</a> - Man-Pages</li>
  <li><a href="pdf4tcl">pdf4tcl</a> - HTML-Reports</li>
</ul>
<h2>Scroll-Test</h2>
<p>Zeile 1: Lorem ipsum dolor sit amet consectetur adipiscing elit.</p>
<p>Zeile 2: Sed do eiusmod tempor incididunt ut labore et dolore magna.</p>
<p>Zeile 3: Ut enim ad minim veniam quis nostrud exercitation.</p>
<p>Zeile 4: Duis aute irure dolor in reprehenderit in voluptate velit.</p>
<p>Zeile 5: Excepteur sint occaecat cupidatat non proident deserunt.</p>
<p>Zeile 6: In culpa qui officia deserunt mollit anim id est laborum.</p>
<p>Ende.</p>
</body></html>
}
