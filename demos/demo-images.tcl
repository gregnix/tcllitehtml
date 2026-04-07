#!/usr/bin/env wish
set _dir [file normalize [file dirname [info script]]]
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

wm title . "tcllitehtml Bilder-Demo"
wm geometry . 820x700
bind . <Escape> { destroy . }

frame .f
pack .f -fill both -expand 1
scrollbar .f.sb -orient vertical -command {.f.html yview}
tcllitehtml::widget .f.html -width 780 -background white \
    -yscrollcommand {.f.sb set}
pack .f.sb -side right -fill y
pack .f.html -side left -fill both -expand 1

set imgdir [file join $_dir ../tests/images]

.f.html load "<html><head>
<style>
  body { font-family: Sans; font-size: 13px; margin: 15px; }
  h1 { color: #2040a0; }
  h2 { color: #4060c0; margin-top: 15px; }
  img { border: 1px solid #ccc; margin: 5px; vertical-align: middle; }
  .box { background: #f0f4ff; border: 1px solid #c0d0f0;
         padding: 10px; margin: 8px 0; }
  .label { color: #666; font-size: 11px; margin: 0 5px; }
</style></head><body>
<h1>Bilder-Demo</h1>

<h2>Lokale Bilder (absoluter Pfad)</h2>
<div class='box'>
  <img src='$imgdir/test.ppm' width='100' height='50'>
  <span class='label'>100x50 (PPM blau)</span>
  <img src='$imgdir/logo.ppm' width='64' height='64'>
  <span class='label'>64x64 (PPM orange)</span>
</div>

<h2>Inline-Bild via _setimage</h2>
<div class='box'>
  <img src='dynamic://gruen-bild' width='150' height='80'>
  <span class='label'>dynamisch gesetzt</span>
</div>

<h2>CSS Hintergrundbild (repeat)</h2>
<div style='background-image: url($imgdir/bg.ppm);
     background-repeat: repeat;
     width: 300px; height: 120px;
     border: 1px solid #999;'></div>

<h2>CSS Hintergrundbild (no-repeat)</h2>
<div style='background-image: url($imgdir/bg.ppm);
     background-repeat: no-repeat;
     background-position: center;
     width: 300px; height: 120px;
     border: 1px solid #999;
     background-color: #e8eef8;'></div>

</body></html>"

# _setimage: gruenes Bild dynamisch erstellen und injizieren
image create photo _dynimg -width 150 -height 80
# Gruen fuellen
for {set y 0} {$y < 80} {incr y} {
    for {set x 0} {$x < 150} {incr x} {
        set r [expr {50 + $x}]
        set g [expr {150 + $y}]
        set b 80
        _dynimg put [format "#%02x%02x%02x" $r $g $b] -to $x $y
    }
}
tcllitehtml::_setimage .f.html "dynamic://gruen-bild" _dynimg
