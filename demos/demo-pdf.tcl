#!/usr/bin/env wish
# demo-pdf.tcl — HTML auf Canvas, PDF via postscript + ps2pdf oder pdf4tcl
#
# Erkenntnis: $pdf canvas .f.html (Widget-Path, nicht Canvas-Befehlsname)
# pdf4tcl liefert bessere Qualität als ps2pdf (kein justify-Problem)

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
package require pdf4tcl

wm title . "tcllitehtml → Canvas → PDF"
wm geometry . 700x600
bind . <Escape> { destroy . }

# Toolbar
frame .tb -relief raised -bd 1
pack .tb -fill x
button .tb.pdf  -text "PDF via ps2pdf"  -command export_pdf_ps
button .tb.pdf2 -text "PDF via pdf4tcl" -command export_pdf_p4t
label  .tb.status -text "" -anchor w
pack .tb.pdf .tb.pdf2 -side left -padx 6 -pady 4
pack .tb.status -side left -padx 10

# HTML-Widget
frame .f
pack .f -fill both -expand 1
scrollbar .f.sb -orient vertical -command {.f.html yview}
tcllitehtml::widget .f.html -background white \
    -yscrollcommand {.f.sb set}
pack .f.sb   -side right -fill y
pack .f.html -side left -fill both -expand 1

# Inhalt
.f.html load {<html><head>
<style>
  body { font-family: Helvetica; font-size: 13px; margin: 16px; }
  h1   { color: #2040a0; border-bottom: 2px solid #2040a0; }
  h2   { color: #4060c0; }
  p    { line-height: 1.5; }
  pre  { background: #f0f0f0; padding: 10px; font-size: 11px;
         border-left: 4px solid #999; font-family: Courier; }
  table { border-collapse: collapse; width: 80%; margin: 10px 0; }
  th   { background: #2040a0; color: white; padding: 5px 10px; }
  td   { border: 1px solid #ccc; padding: 4px 10px; }
  tr:nth-child(even) td { background: #f0f4ff; }
</style>
</head><body>
<h1>tcllitehtml Canvas PDF Export</h1>
<p>Dieser Text wird von <b>litehtml</b> auf einem Tk Canvas gerendert.
Der Canvas wird mit <b>postscript</b> exportiert und dann mit
<b>ps2pdf</b> zu PDF konvertiert.</p>

<h2>Vorgehensweise</h2>
<p>Der Tcl-Befehl <code>$cv postscript</code> erzeugt aus dem Canvas-Inhalt
eine PostScript-Datei. Das Werkzeug <b>ps2pdf</b> (Ghostscript) konvertiert
diese dann zu PDF. Vorteil: exakt das was sichtbar ist landet im PDF &mdash;
kein Umrechnungsproblem.</p>

<h2>Feature-Uebersicht</h2>
<table>
  <tr><th>Feature</th><th>Status</th><th>Version</th></tr>
  <tr><td>HTML5 + CSS2/3</td><td>&#10004;</td><td>0.1.0</td></tr>
  <tr><td>Scrollbar</td><td>&#10004;</td><td>0.1.0</td></tr>
  <tr><td>Text Selection</td><td>&#10004;</td><td>0.1.0</td></tr>
  <tr><td>CSS via HTTP</td><td>&#10004;</td><td>0.1.0</td></tr>
  <tr><td>Canvas -&gt; PDF</td><td>&#10004;</td><td>0.1.0</td></tr>
</table>

<h2>Code</h2>
<pre>set cv [.html cget -canvas]
$cv postscript -file output.ps -pagewidth 595p
exec ps2pdf output.ps output.pdf</pre>

<p>Das ist Seite 1. Weitere Inhalte folgen auf den n&auml;chsten Seiten.</p>
<p>Lorem ipsum dolor sit amet. Tcl wurde 1988 von John Ousterhout entwickelt.
Tk ist das GUI-Toolkit. Zusammen sind sie eine m&auml;chtige Kombination.</p>
<p>litehtml ist eine leichtgewichtige HTML/CSS-Engine unter BSD-Lizenz.
Sie implementiert HTML5 und CSS2/3 ohne Browser-Engine.</p>
</body></html>}

# ============================================================
proc export_pdf_ps {} {
    set outfile [tk_getSaveFile \
        -defaultextension .pdf \
        -filetypes {{PDF .pdf} {Alle *.*}} \
        -initialfile "output.pdf" \
        -title "PDF speichern als"]
    if {$outfile eq ""} return

    if {[auto_execok ps2pdf] eq ""} {
        .tb.status configure -text "Fehler: ps2pdf nicht gefunden"
        return
    }

    set cv [.f.html cget -canvas]
    set psfile [file rootname $outfile].ps

    $cv postscript \
        -pagewidth  595p \
        -pageheight 842p \
        -file $psfile

    if {[catch { exec ps2pdf $psfile $outfile } err]} {
        .tb.status configure -text "Fehler: $err"
        return
    }

    file delete -force $psfile
    .tb.status configure -text "ps2pdf OK → $outfile"
}

# ============================================================
# pdf4tcl canvas: Widget-Path (.f.html), nicht den internen Canvas-Befehlsnamen!
# Das Tk-Fenster existiert noch unter .f.html — nur der Tcl-Befehl wurde umbenannt.
proc export_pdf_p4t {} {
    set outfile [tk_getSaveFile \
        -defaultextension .pdf \
        -filetypes {{PDF .pdf} {Alle *.*}} \
        -initialfile "output-p4t.pdf" \
        -title "PDF speichern als"]
    if {$outfile eq ""} return

    update idletasks

    # Widget-Path verwenden (nicht $cv — der interne Befehlsname funktioniert nicht)
    set wp .f.html
    set bbox [$wp bbox all]
    if {$bbox eq ""} {
        .tb.status configure -text "Canvas leer"
        return
    }
    lassign $bbox x1 y1 x2 y2
    set cw [expr {$x2 - $x1}]
    set ch [expr {$y2 - $y1}]

    set scale  [expr {500.0 / $cw}]
    set pdf_w  [expr {$cw * $scale}]
    set pdf_h  [expr {$ch * $scale}]

    set pdf [::pdf4tcl::new %AUTO%         -paper [list $pdf_w $pdf_h]         -orient true -compress 1]

    # TTF-Font für Unicode (✔ etc.) — DejaVu auf Debian/Ubuntu
    foreach ttf {
        /usr/share/fonts/truetype/dejavu/DejaVuSans.ttf
        /usr/share/fonts/TTF/DejaVuSans.ttf
        /usr/share/fonts/dejavu/DejaVuSans.ttf
    } {
        if {[file exists $ttf]} {
            catch { $pdf loadFont $ttf -encoding utf-8 }
            break
        }
    }

    $pdf startPage
    # fontmap: Tk-Fontname → TTF-Datei für Unicode-Zeichen (✔ etc.)
    set fontmap {}
    foreach {tk ttf} {
        Helvetica /usr/share/fonts/truetype/dejavu/DejaVuSans.ttf
        Courier   /usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf
    } {
        if {[file exists $ttf]} {
            lappend fontmap $tk $ttf
        }
    }

    $pdf canvas $wp \
        -fontmap $fontmap \
        -bbox $bbox \
        -x 20 -y 20 \
        -width  [expr {$pdf_w - 40}] \
        -height [expr {$pdf_h - 40}]
    $pdf endPage
    $pdf write -file $outfile
    $pdf destroy

    .tb.status configure -text "pdf4tcl OK → $outfile"
}
