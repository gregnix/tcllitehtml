#!/usr/bin/env wish
# demo-links.tcl -- Link-Callback Demo
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

wm title . "tcllitehtml Links-Demo"
wm geometry . 820x650
bind . <Escape> { destroy . }

# Status-Zeile
frame .status -bd 1 -relief sunken
label .status.lbl -text "Klick auf einen Link..." -anchor w
pack .status.lbl -fill x -padx 4

frame .f
pack .status -side bottom -fill x
pack .f      -fill both -expand 1

scrollbar .f.sb -orient vertical -command {.f.html yview}
tcllitehtml::widget .f.html \
    -width 780 \
    -background white \
    -yscrollcommand {.f.sb set} \
    -command {apply {{url} {
        .status.lbl configure -text "Link: $url"
        puts "Geklickt: $url"
    }}}

pack .f.sb   -side right -fill y
pack .f.html -side left  -fill both -expand 1

.f.html load {
<html><head>
<style>
  body { font-family: Sans; font-size: 14px; margin: 20px; }
  h1 { color: #2040a0; }
  h2 { color: #4060c0; }
  a  { color: #2060d0; text-decoration: underline; }
  a:hover { color: #f04000; }
  .box { background: #f0f4ff; border: 1px solid #c0d0f0;
         padding: 10px; margin: 10px 0; }
  ul { margin-left: 20px; }
  li { margin: 6px 0; }
</style></head><body>

<h1>Links Demo</h1>
<p>Klick auf Links -&gt; Callback in Tcl</p>

<div class="box">
<h2>Externe Links</h2>
<ul>
  <li><a href="https://github.com/litehtml/litehtml">litehtml auf GitHub</a></li>
  <li><a href="https://www.tcl-lang.org/">Tcl/Tk Homepage</a></li>
  <li><a href="https://wiki.tcl-lang.org/">Tcl Wiki</a></li>
</ul>
</div>

<div class="box">
<h2>Interne Navigation</h2>
<ul>
  <li><a href="#abschnitt1">Springe zu Abschnitt 1</a></li>
  <li><a href="#abschnitt2">Springe zu Abschnitt 2</a></li>
  <li><a href="page:home">Startseite</a></li>
  <li><a href="page:hilfe">Hilfe</a></li>
</ul>
</div>

<div class="box">
<h2>Aktionen (Custom-URLs)</h2>
<ul>
  <li><a href="action:drucken">Dokument drucken</a></li>
  <li><a href="action:exportieren">Als PDF exportieren</a></li>
  <li><a href="action:suchen">Suchen...</a></li>
</ul>
</div>

<h2 id="abschnitt1">Abschnitt 1</h2>
<p>Inhalt von Abschnitt 1.</p>

<h2 id="abschnitt2">Abschnitt 2</h2>
<p>Inhalt von Abschnitt 2.</p>

</body></html>
}
