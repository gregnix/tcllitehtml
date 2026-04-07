#!/usr/bin/env wish
# demo-css.tcl -- CSS-Features Demo
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

wm title . "tcllitehtml CSS-Demo"
wm geometry . 820x700
bind . <Escape> { destroy . }

frame .f
pack .f -fill both -expand 1
scrollbar .f.sb -orient vertical -command {.f.html yview}
tcllitehtml::widget .f.html -width 780 -background white \
    -yscrollcommand {.f.sb set}
pack .f.sb -side right -fill y
pack .f.html -side left -fill both -expand 1

.f.html load {
<html><head>
<style>
  body { font-family: Sans; font-size: 13px; margin: 15px; }
  h1 { color: #2040a0; font-size: 22px; border-bottom: 2px solid #2040a0; }
  h2 { color: #4060c0; font-size: 16px; margin-top: 18px; }
  h3 { color: #6080e0; font-size: 14px; }

  /* Tabellen */
  table { border-collapse: collapse; width: 100%; margin: 8px 0; }
  th { background: #2040a0; color: white; padding: 5px 8px; font-size: 12px; }
  td { border: 1px solid #ccc; padding: 4px 8px; }
  tr:nth-child(even) td { background: #f0f4ff; }
  tr:nth-child(odd)  td { background: white; }

  /* Listen */
  ul { margin-left: 20px; }
  ol { margin-left: 20px; }
  li { margin: 3px 0; }

  /* Code */
  code { background: #eef; padding: 1px 4px;
         font-family: Monospace; font-size: 12px; }
  pre  { background: #f4f4f4; border: 1px solid #ddd;
         padding: 8px; font-family: Monospace; font-size: 12px; }

  /* Farben */
  .red    { color: #cc0000; }
  .green  { color: #008800; }
  .blue   { color: #0000cc; }
  .bold   { font-weight: bold; }
  .italic { font-style: italic; }

  /* Box-Modell */
  .box    { border: 1px solid #c0c0e0; padding: 8px;
            margin: 8px 0; background: #f8f8ff; }
  .note   { border-left: 4px solid #f0c000; padding: 6px 10px;
            background: #fffbe6; margin: 8px 0; }
  .warn   { border-left: 4px solid #cc0000; padding: 6px 10px;
            background: #fff0f0; margin: 8px 0; }
</style></head><body>

<h1>CSS-Features Demo</h1>

<h2>Textformatierung</h2>
<p>Normal, <b>fett</b>, <i>kursiv</i>, <b><i>fett+kursiv</i></b>,
<code>code</code>, <span class="red">rot</span>,
<span class="green">gr&uuml;n</span>, <span class="blue">blau</span>.</p>

<h2>&Uuml;berschriften h1-h6</h2>
<h1>&Uuml;berschrift 1</h1>
<h2>&Uuml;berschrift 2</h2>
<h3>&Uuml;berschrift 3</h3>

<h2>Listen</h2>
<div style="display:inline-block; width:45%; vertical-align:top;">
<b>Ungeordnet:</b>
<ul>
  <li>Punkt 1</li>
  <li>Punkt 2
    <ul><li>Unterp. 2.1</li><li>Unterp. 2.2</li></ul>
  </li>
  <li>Punkt 3</li>
</ul>
</div>
<div style="display:inline-block; width:45%; vertical-align:top;">
<b>Geordnet:</b>
<ol>
  <li>Erster</li>
  <li>Zweiter</li>
  <li>Dritter</li>
</ol>
</div>

<h2>Tabellen</h2>
<table>
  <tr><th>Sprache</th><th>Typ</th><th>Version</th><th>Lizenz</th></tr>
  <tr><td>Tcl/Tk</td><td>Skript</td><td>8.6 / 9.0</td><td>BSD</td></tr>
  <tr><td>C++</td><td>Kompiliert</td><td>C++17</td><td>&#8212;</td></tr>
  <tr><td>litehtml</td><td>Bibliothek</td><td>master</td><td>BSD</td></tr>
</table>

<h2>Box-Modell</h2>
<div class="box">Normale Box mit Rahmen und Hintergrund.</div>
<div class="note">Hinweis: gelbe linke Linie (border-left).</div>
<div class="warn">Warnung: rote linke Linie.</div>

<h2>Code</h2>
<pre>proc greet {name} {
    puts "Hallo, $name!"
}
greet "Welt"</pre>

</body></html>
}
