#!/usr/bin/env wish
set _dir [file normalize [file dirname [info script]]]
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

wm title . "tcllitehtml Tabellen-Demo"
wm geometry . 820x620
bind . <Escape> { destroy . }

# Frame f&uuml;llt das gesamte Fenster
frame .f
pack .f -fill both -expand 1

# Scrollbar + Widget ohne feste H&ouml;he
scrollbar .f.sb -orient vertical -command {.f.html yview}
tcllitehtml::widget .f.html \
    -width 780 \
    -background white \
    -yscrollcommand {.f.sb set}

pack .f.sb   -side right -fill y
pack .f.html -side left  -fill both -expand 1

.f.html load {
<html><head>
<style>
  body  { font-family: Sans; font-size: 13px; margin: 15px; }
  h2    { color: #2040a0; }
  table { border-collapse: collapse; margin: 10px 0; width: 100%; }
  th    { background: #2040a0; color: white; padding: 5px 10px;
          border: 1px solid #1030a0; }
  td    { padding: 4px 10px; border: 1px solid #ccc; }
  tr:nth-child(even) td { background: #f4f4fb; }
</style></head><body>

<h2>Einfache Tabelle</h2>
<table>
  <tr><th>Name</th><th>Version</th><th>Lizenz</th><th>Status</th></tr>
  <tr><td>TkMoin</td><td>0.1.0</td><td>BSD</td><td>aktiv</td></tr>
  <tr><td>pdf4tcl</td><td>0.9.4.25</td><td>BSD</td><td>aktiv</td></tr>
  <tr><td>mdstack</td><td>0.3.3</td><td>BSD</td><td>aktiv</td></tr>
  <tr><td>tcllitehtml</td><td>0.1.0</td><td>BSD</td><td>in Entwicklung</td></tr>
</table>

<h2>colspan</h2>
<table>
  <tr><th colspan="2">Plattform</th><th colspan="2">Tcl</th></tr>
  <tr><th>Linux</th><th>Windows</th><th>8.6</th><th>9.0</th></tr>
  <tr><td>OK</td><td>BAWT</td><td>OK</td><td>OK</td></tr>
</table>

<h2>rowspan</h2>
<table>
  <tr><th rowspan="3">TkMoin</th><td>libtkmoin_scene.so</td><td>Scene-Graph</td></tr>
  <tr><td>libtkmoin_utils.so</td><td>Cairou + Layout</td></tr>
  <tr><td>libtkmoin_wayland.so</td><td>Wayland-Backend</td></tr>
</table>

<h2>Scroll-Test</h2>
<table>
  <tr><th>Nr</th><th>Inhalt</th></tr>
  <tr><td>1</td><td>Erste Zeile</td></tr>
  <tr><td>2</td><td>Zweite Zeile</td></tr>
  <tr><td>3</td><td>Dritte Zeile</td></tr>
  <tr><td>4</td><td>Vierte Zeile</td></tr>
  <tr><td>5</td><td>Fuenfte Zeile</td></tr>
  <tr><td>6</td><td>Sechste Zeile</td></tr>
  <tr><td>7</td><td>Siebte Zeile</td></tr>
  <tr><td>8</td><td>Achte Zeile</td></tr>
  <tr><td>9</td><td>Neunte Zeile</td></tr>
  <tr><td>10</td><td>Zehnte Zeile</td></tr>
</table>
</body></html>
}
