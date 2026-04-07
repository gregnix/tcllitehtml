#!/usr/bin/env wish
set _dir [file normalize [file dirname [info script]]]
if {$::tcl_platform(platform) eq "windows"} {
    load [file join $_dir ../lib/libtcllitehtml.dll]
} elseif {[package vsatisfies [package provide Tcl] 9.0-]} {
    set _lib9 [file join $_dir ../lib/libtcllitehtml9.so]
    set _lib  [file join $_dir ../lib/libtcllitehtml.so]
    if {[file exists $_lib9]} { set _lib $_lib9 }
    load $_lib
} else {
    load [file join $_dir ../lib/libtcllitehtml.so]
}
source [file join $_dir ../tcl/tcllitehtml/widget-0.1.tm]

wm title . "tcllitehtml Selection-Demo"
wm geometry . 820x700
bind . <Escape> { destroy . }

# Toolbar
frame .tb -relief raised -bd 1
pack .tb -fill x

button .tb.sel -text "Selection ein/aus" -command {
    if {[winfo exists .f.html_sel]} {
        ::tcllitehtml::selection_stop .f.html
        .tb.sel configure -relief raised
        .tb.info configure -text "Selection aus"
    } else {
        ::tcllitehtml::selection_start .f.html
        .tb.sel configure -relief sunken
        .tb.info configure -text "Selection: Maus ziehen → Clipboard"
    }
}
button .tb.all -text "Alles kopieren (Ctrl+A)" -command {
    ::tcllitehtml::_copy_all .f.html
    .tb.info configure -text "Alles in Clipboard"
}
label .tb.info -text "Ctrl+A = alles | Selection-Button = Maus-Markierung"
pack .tb.sel .tb.all -side left -padx 4 -pady 3
pack .tb.info -side left -padx 10

# HTML-Widget
frame .f
pack .f -fill both -expand 1
scrollbar .f.sb -orient vertical -command {.f.html yview}
tcllitehtml::widget .f.html -background white \
    -yscrollcommand {.f.sb set}
pack .f.sb -side right -fill y
pack .f.html -side left -fill both -expand 1

# Focus
bind . <Control-a> { ::tcllitehtml::_copy_all .f.html; .tb.info configure -text "Alles kopiert!" }

.f.html load {<html><head>
<style>
  body  { font-family: Sans; font-size: 13px; margin: 15px; }
  h1    { color: #2040a0; }
  h2    { color: #4060c0; margin-top: 12px; }
  p     { margin: 6px 0; }
  pre   { background: #f0f0f0; border-left: 3px solid #999;
          padding: 8px; font-family: Monospace; font-size: 12px; }
  code  { background: #f0f0f0; padding: 1px 4px; font-family: Monospace; }
  .box  { background: #f0f4ff; border: 1px solid #c0d0f0;
          padding: 10px; margin: 8px 0; }
  table { border-collapse: collapse; margin: 8px 0; }
  th    { background: #2040a0; color: white; padding: 4px 10px; }
  td    { border: 1px solid #ccc; padding: 3px 8px; }
</style>
</head><body>

<h1>Selection und Clipboard</h1>

<div class='box'>
  <b>Bedienung im Selection-Modus:</b><br>
  1x Klick = Wort | 2x Klick = Zeile | Maus ziehen = Zeilen-Bereich<br>
  <code>Ctrl+A</code> = alles kopieren (auch ohne Selection-Modus)
</div>

<h2>Normaler Text</h2>
<p>Das ist ein einfacher Absatz mit normalem Text.
Hier steht mehr Text damit man etwas ausw&auml;hlen kann.
Tcl/Tk ist eine gro&szlig;artige Skriptsprache.</p>

<p>Ein zweiter Absatz. litehtml rendert HTML5 und CSS2/3.
Der Text wird pixel-genau auf das Tk-Canvas gezeichnet.</p>

<h2>Code-Block</h2>
<pre>proc greet {name} {
    puts "Hallo, $name!"
    return [string length $name]
}

greet "Welt"</pre>

<h2>Tabelle</h2>
<table>
  <tr><th>Sprache</th><th>Typ</th><th>Version</th></tr>
  <tr><td>Tcl</td><td>Skript</td><td>8.6 / 9.0</td></tr>
  <tr><td>C++</td><td>Kompiliert</td><td>C++17</td></tr>
  <tr><td>litehtml</td><td>Bibliothek</td><td>master</td></tr>
</table>

<h2>Links</h2>
<p>Ein Link: <a href="https://www.tcl-lang.org/">www.tcl-lang.org</a>.
Noch ein Link: <a href="https://github.com/litehtml/litehtml">litehtml auf GitHub</a>.</p>

<h2>Langer Text zum Scrollen</h2>
<p>Lorem ipsum dolor sit amet, consectetur adipiscing elit.
Tcl wurde 1988 von John Ousterhout entwickelt. Tk wurde als
grafische Erweiterung dazu gebaut. Zusammen bilden sie eine
m&auml;chtige Kombination f&uuml;r GUI-Anwendungen.</p>
<p>Die litehtml-Engine implementiert einen CSS-Layout-Engine der
HTML5 und CSS2/3 versteht. Tabellen mit colspan und rowspan,
Listen, Fonts, Farben und Hintergr&uuml;nde werden unterst&uuml;tzt.</p>
<p>tcllitehtml verbindet litehtml mit Tk-Canvas. Das Widget
verhält sich wie ein normales Tk-Widget mit pack, grid und place.
Scrollbar, Mausrad, Hover und Link-Callbacks funktionieren.</p>

</body></html>}

focus .f.html
