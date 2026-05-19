# widget-0.1.tm -- tcllitehtml public Tcl API
# Copyright (c) 2026 Gregor Ebbing, BSD

namespace eval ::tcllitehtml {
    variable _widgets  ;# path → {cv}
}

# ----------------------------------------------------------------
# Event-Helper (Stufe 2 Fix für Click/Motion mit canvasy)
# Saubere Helper-Procs vermeiden geschachteltes Quoting in Bindings.
# ----------------------------------------------------------------

proc ::tcllitehtml::_click_event {path x y} {
    variable _widgets
    if {![info exists _widgets($path)]} return
    set cv [dict get $_widgets($path) cv]
    set cy [expr {int([$cv canvasy $y])}]
    catch {tcllitehtml::_click $path $x $cy}
}

proc ::tcllitehtml::_motion_event {path x y} {
    variable _widgets
    if {![info exists _widgets($path)]} return
    set cv [dict get $_widgets($path) cv]
    set cy [expr {int([$cv canvasy $y])}]
    catch {tcllitehtml::_mouse $path $x $cy}
}

proc ::tcllitehtml::widget {path args} {
    variable _widgets

    set width         800
    set height        0     ;# 0 = kein -height gesetzt
    set bg            white
    # Font: Sans auf Linux, Arial auf Windows
    if {$::tcl_platform(platform) eq "windows"} {
        set font Arial
    } else {
        set font Sans
    }
    set fsize         13
    set yscrollcmd    ""
    set on_link_click ""
    set openurl_handler ""

    foreach {opt val} $args {
        switch -- $opt {
            -width          { set width         $val }
            -height         { set height        $val }
            -background     { set bg            $val }
            -font           { set font          $val }
            -yscrollcommand { set yscrollcmd    $val }
            -command        { set on_link_click $val }
            -fontsize       { set fsize $val }
            -openurl        {
                if {$val eq "1" || $val eq "default"} {
                    set openurl_handler "::tcllitehtml::_open_url"
                } else {
                    set openurl_handler $val
                }
            }
        }
    }
    # -openurl: Standard-Browser-Handler (nur wenn kein -command gesetzt)
    if {[info exists openurl_handler] && $on_link_click eq ""} {
        set on_link_click $openurl_handler
    }

    # Tk-Canvas erzeugen
    # height=0 (default): kein -height → pack fill both -expand 1 bestimmt Größe
    if {$height <= 0} {
        set canvas_args [list canvas $path -width $width -background $bg -bd 0 -highlightthickness 0]
    } else {
        set canvas_args [list canvas $path -width $width -height $height -background $bg -bd 0 -highlightthickness 0]
    }
    {*}$canvas_args

    # litehtml-Backend
    try {
        tcllitehtml::_init $path $width $height \
            $font $fsize $bg $yscrollcmd $on_link_click
    } on error {msg opts} {
        catch {destroy $path}
        return -code error "tcllitehtml::_init: $msg"
    }

    # Stufe 2: yscrollcommand direkt auf Canvas — Tk macht das selbst
    if {$yscrollcmd ne ""} {
        $path configure -yscrollcommand $yscrollcmd
    }

    # Canvas-Command umbenennen (Fenster bleibt, Delete-Proc läuft nicht)
    set cv "::tcllitehtml::_cv[string map {. _ - _} $path]"
    rename $path $cv

    # Alias anlegen (kein altes Command → kein Delete-Trigger)
    interp alias {} $path {} ::tcllitehtml::_dispatch $path $cv

    # Stufe 2: Mausrad nutzt Tk-natives yview (gratis, kein Re-Render)
    bind $path <Button-4>    "$cv yview scroll -3 units"
    bind $path <Button-5>    "$cv yview scroll  3 units"
    bind $path <MouseWheel>  "$cv yview scroll \[expr {-%D/30}] units"

    # Stufe 2 (Fix): Click + Motion via Helper-Proc — vermeidet
    # geschachteltes Quoting in Bind-Strings
    bind $path <Button-1>    [list ::tcllitehtml::_click_event  $path %x %y]
    bind $path <Motion>      [list ::tcllitehtml::_motion_event $path %x %y]

    # Resize-Event
    bind $path <Configure>   "::tcllitehtml::_on_configure [list $path] %w %h"
    bind $path <Destroy>     "::tcllitehtml::_on_destroy [list $path]"
    # Ctrl+A = alles kopieren
    bind $path <Control-a>   "::tcllitehtml::_copy_all [list $path]"
    bind $path <Control-A>   "::tcllitehtml::_copy_all [list $path]"
    # Ctrl+C = kopieren wenn Selection aktiv
    bind $path <Control-c>   "::tcllitehtml::_copy_selection [list $path]"
    bind $path <Control-C>   "::tcllitehtml::_copy_selection [list $path]"

    set _widgets($path) [dict create cv $cv font $font fsize $fsize \
        command $on_link_click yscrollcmd $yscrollcmd]
    return $path
}

# Destroy-Handler: C++ State freigeben
proc ::tcllitehtml::_on_destroy {path} {
    variable _widgets
    # Stufe 1: ausstehenden Resize-Timer canceln
    if {[info exists _widgets($path,_resize_after)]} {
        catch {after cancel $_widgets($path,_resize_after)}
        unset _widgets($path,_resize_after)
    }
    catch { tcllitehtml::_destroy $path }
    catch { unset _widgets($path) }
}

# Standard URL-Handler: öffnet Browser plattformübergreifend
proc ::tcllitehtml::_open_url {url} {
    # Nur http/https öffnen — interne Links ignorieren
    if {![string match "http*" $url]} return
    switch $::tcl_platform(platform) {
        windows { catch {exec cmd /c start "" $url &} }
        unix    {
            if {[catch {exec xdg-open $url &}]} {
                catch {exec x-www-browser $url &}
            }
        }
        default { catch {exec open $url &} }
    }
}

# ================================================================
# Selection
# ================================================================

# Selection-Modus aktivieren: Bindings direkt auf Canvas
proc ::tcllitehtml::selection_start {path} {
    variable _widgets
    if {![info exists _widgets($path)]} return
    if {[info exists ::tcllitehtml::_sel($path,active)]} return
    set cv [dict get $_widgets($path) cv]
    set ::tcllitehtml::_sel($path,x1) -1
    set ::tcllitehtml::_sel($path,y1) -1
    set ::tcllitehtml::_sel($path,active) 1
    set ::tcllitehtml::_sel($path,cv) $cv
    $cv configure -cursor crosshair
    # Stufe 2: %y → canvasy weil Selection-Logic Canvas-Items findet
    bind $path <Button-1>        "::tcllitehtml::_sel_start    [list $path] %x \[$cv canvasy %y]"
    bind $path <B1-Motion>       "::tcllitehtml::_sel_drag     [list $path] %x \[$cv canvasy %y]"
    bind $path <ButtonRelease-1> "::tcllitehtml::_sel_end      [list $path] %x \[$cv canvasy %y]"
    bind $path <Double-Button-1> "::tcllitehtml::_sel_dblclick [list $path] %x \[$cv canvasy %y]"
    bind $path <Escape>          [list ::tcllitehtml::selection_stop $path]
    focus $path
}

proc ::tcllitehtml::selection_stop {path} {
    if {![info exists ::tcllitehtml::_sel($path,active)]} return
    set cv $::tcllitehtml::_sel($path,cv)
    $cv delete sel_rect
    $cv configure -cursor {}
    # Originale Bindings wiederherstellen (Stufe 2 Fix: Helper-Proc)
    bind $path <Button-1>        [list ::tcllitehtml::_click_event $path %x %y]
    bind $path <B1-Motion>       {}
    bind $path <ButtonRelease-1> {}
    bind $path <Double-Button-1> {}
    bind $path <Escape>          {}
    array unset ::tcllitehtml::_sel ${path},*
}

proc ::tcllitehtml::selection_clear {path} {
    if {![info exists ::tcllitehtml::_sel($path,cv)]} return
    $::tcllitehtml::_sel($path,cv) delete sel_rect
    set ::tcllitehtml::_sel($path,x1) -1
}

# --- Hilfsfunktion: TextItem unter Mauszeiger finden ---
# Gibt Liste von Items auf gleicher Y-Zeile zurück (für Doppelklick)
# Gibt einzelnes Item zurück (für Einzelklick)
proc ::tcllitehtml::_items_at {path x y} {
    # Alle TextItems vom C++ holen via _gettext ist zu grob
    # → Canvas-Items unter Cursor finden
    set cv $::tcllitehtml::_sel($path,cv)
    set hit [$cv find closest $x $y]
    return $hit
}

# --- Einzelklick: Wort unter Cursor markieren ---
proc ::tcllitehtml::_sel_start {path x y} {
    set ::tcllitehtml::_sel($path,x1) $x
    set ::tcllitehtml::_sel($path,y1) $y
    set ::tcllitehtml::_sel($path,dragging) 0
    $::tcllitehtml::_sel($path,cv) delete sel_rect
}

# --- Drag: Zeilen-basierte Selektion ---
proc ::tcllitehtml::_sel_drag {path x y} {
    set x1 $::tcllitehtml::_sel($path,x1)
    set y1 $::tcllitehtml::_sel($path,y1)
    if {$x1 < 0} return
    set ::tcllitehtml::_sel($path,dragging) 1
    set cv $::tcllitehtml::_sel($path,cv)
    $cv delete sel_rect

    # Zeilenbasiert: von y1 bis y — alle Items die in Zeilen liegen
    set ly [expr {min($y1,$y)}]
    set ry [expr {max($y1,$y)}]

    # Zeilen-Rechteck: volle Breite des Widgets
    set w [winfo width $path]
    $cv create rectangle 0 $ly $w $ry         -fill #4080ff -stipple gray25         -outline #2060df -width 1 -tags sel_rect
    $cv raise sel_rect
}

# --- Button-Release: Text sammeln ---
proc ::tcllitehtml::_sel_end {path x y} {
    set x1 $::tcllitehtml::_sel($path,x1)
    set y1 $::tcllitehtml::_sel($path,y1)
    set dragging $::tcllitehtml::_sel($path,dragging)
    if {$x1 < 0} return

    set cv $::tcllitehtml::_sel($path,cv)
    set w [winfo width $path]

    if {!$dragging} {
        # Zuerst: Link-Klick weiterleiten (wie normaler Modus)
        catch { tcllitehtml::_click $path $x $y }

        # Einzelklick → Wort unter Cursor markieren
        set hit [$cv find closest $x $y 5]
        if {$hit eq ""} {
            ::tcllitehtml::selection_clear $path
            return
        }
        set bbox [$cv bbox $hit]
        if {$bbox eq ""} {
            ::tcllitehtml::selection_clear $path
            return
        }
        lassign $bbox ix1 iy1 ix2 iy2
        $cv delete sel_rect
        $cv create rectangle $ix1 $iy1 $ix2 $iy2             -fill #4080ff -stipple gray25             -outline #2060df -width 1 -tags sel_rect
        $cv raise sel_rect
        set text [tcllitehtml::_gettext $path $ix1 $iy1 $ix2 $iy2]
    } else {
        # Drag → Zeilen-Rechteck
        set ly [expr {min($y1,$y)}]
        set ry [expr {max($y1,$y)}]
        set text [tcllitehtml::_gettext $path 0 $ly $w $ry]
    }

    if {$text ne ""} {
        clipboard clear
        clipboard append $text
        catch {
            selection own -command [list ::tcllitehtml::_sel_lost $path] .
            selection handle . [list ::tcllitehtml::_sel_provide $text]
        }
    }
}

# --- Doppelklick: ganze Zeile markieren ---
proc ::tcllitehtml::_sel_dblclick {path x y} {
    if {![info exists ::tcllitehtml::_sel($path,cv)]} return
    set cv $::tcllitehtml::_sel($path,cv)

    # Item unter Cursor finden → Y-Koordinaten der Zeile
    set hit [$cv find closest $x $y 5]
    if {$hit eq ""} return
    set bbox [$cv bbox $hit]
    if {$bbox eq ""} return
    lassign $bbox ix1 iy1 ix2 iy2

    # Alle Items auf gleicher Zeile finden (gleiche Y-Range)
    set w [winfo width $path]
    set margin 3
    $cv delete sel_rect
    $cv create rectangle 0 [expr {$iy1-$margin}] $w [expr {$iy2+$margin}]         -fill #4080ff -stipple gray25         -outline #2060df -width 1 -tags sel_rect
    $cv raise sel_rect

    set text [tcllitehtml::_gettext $path         0 [expr {$iy1-$margin}] $w [expr {$iy2+$margin}]]
    if {$text ne ""} {
        clipboard clear
        clipboard append $text
        catch {
            selection own -command [list ::tcllitehtml::_sel_lost $path] .
            selection handle . [list ::tcllitehtml::_sel_provide $text]
        }
    }
}
# Ctrl+A: gesamten Text in Clipboard
proc ::tcllitehtml::_copy_all {path} {
    set text [tcllitehtml::_gettext $path]
    if {$text ne ""} {
        clipboard clear
        clipboard append $text
    }
}

# Ctrl+C: aktuelle Selektion kopieren (falls aktiv)
proc ::tcllitehtml::_copy_selection {path} {
    if {![info exists ::tcllitehtml::_sel($path,cv)]} return
    set cv $::tcllitehtml::_sel($path,cv)
    set bbox [$cv bbox sel_rect]
    if {$bbox eq ""} return
    lassign $bbox x1 y1 x2 y2
    set text [tcllitehtml::_gettext $path $x1 $y1 $x2 $y2]
    if {$text ne ""} {
        clipboard clear
        clipboard append $text
    }
}

# PRIMARY verloren (anderes Fenster hat übernommen)
proc ::tcllitehtml::_sel_lost {path} {
    ::tcllitehtml::selection_clear $path
}

# PRIMARY Selection bereitstellen
proc ::tcllitehtml::_sel_provide {text offset maxbytes} {
    string range $text $offset [expr {$offset + $maxbytes - 1}]
}

# Configure-Handler: Debounce (Stufe 1) — Resize-Events sammeln,
# erst 100 ms nach letztem Event rendern
proc ::tcllitehtml::_on_configure {path w h} {
    variable _widgets
    if {![info exists _widgets($path)]} return
    if {$w < 2 || $h < 2} return   ;# Tk-interne Events ignorieren

    # alten Timer canceln, neuen setzen
    if {[info exists _widgets($path,_resize_after)]} {
        catch {after cancel $_widgets($path,_resize_after)}
    }
    set _widgets($path,_resize_after) [after 100 \
        [list ::tcllitehtml::_do_resize $path $w $h]]
}

# Eigentlicher Resize, jetzt zeitversetzt
proc ::tcllitehtml::_do_resize {path w h} {
    variable _widgets
    unset -nocomplain _widgets($path,_resize_after)
    if {![info exists _widgets($path)]} return
    try {
        set cur_w [tcllitehtml::_info $path width]
        set cur_h [tcllitehtml::_info $path height]
        # Immer resize wenn Höhe sich ändert (wichtig für korrekte doc_height)
        if {$w == $cur_w && $h == $cur_h} return
        tcllitehtml::_resize $path $w $h
    } on error {} {
        # Vor erstem _load: _init mit neuer Größe aktualisieren
        catch { tcllitehtml::_resize $path $w $h }
    }
}

proc ::tcllitehtml::_dispatch {path cv sub args} {
    switch -- $sub {
        load {
            set a [lindex $args 0]
            if {$a eq "-file"} {
                try {
                    set f [open [lindex $args 1] r]
                    set html [read $f]
                    close $f
                } on error {msg} {
                    return -code error "tcllitehtml load -file: $msg"
                }
            } else {
                set html $a
            }
            try {
                tcllitehtml::_load $path $html
            } on error {msg} {
                return -code error "tcllitehtml _load: $msg"
            }
        }
        yview {
            # Stufe 2: alles an Canvas durchreichen — Tk's natives yview
            # macht das Scrolling in C, kein Re-Render in tcllitehtml
            if {[llength $args] == 0} {
                # yview ohne Args: aktuelle fractions zurückgeben
                return [$cv yview]
            }
            $cv yview {*}$args
        }
        configure {
            # Widget-Optionen nachträglich setzen
            variable _widgets
            # Alle relevanten Werte aus gespeichertem State holen
            set _state $_widgets($path)
            set _font        [dict get $_state font]
            set _fsize       [dict get $_state fsize]
            set on_link_click [dict get $_state command]
            set yscrollcmd   [dict get $_state yscrollcmd]
            set _reinit 0
            foreach {opt val} $args {
                switch -- $opt {
                    -command        {
                        set on_link_click $val
                        dict set _widgets($path) command $val
                        set _reinit 1
                    }
                    -yscrollcommand {
                        set yscrollcmd $val
                        dict set _widgets($path) yscrollcmd $val
                        set _reinit 1
                    }
                    -font           {
                        set _font $val
                        dict set _widgets($path) font $val
                        set _reinit 1
                    }
                    -fontsize       {
                        set _fsize $val
                        dict set _widgets($path) fsize $val
                        set _reinit 1
                    }
                    -background { $cv configure -background $val }
                    -width      { $cv configure -width $val }
                    default     { catch { $cv configure $opt $val } }
                }
            }
            if {$_reinit} {
                catch {
                    set _w  [tcllitehtml::_info $path width]
                    set _h  [tcllitehtml::_info $path height]
                    set _bg [$cv cget -background]
                    tcllitehtml::_init $path $_w $_h                         $_font $_fsize $_bg $yscrollcmd $on_link_click
                }
            }
        }
        cget {
            variable _widgets
            set opt [lindex $args 0]
            set _state $_widgets($path)
            switch -- $opt {
                -font           { return [dict get $_state font] }
                -fontsize       { return [dict get $_state fsize] }
                -command        { return [dict get $_state command] }
                -yscrollcommand { return [dict get $_state yscrollcmd] }
                -canvas         { return $cv }
                default         { return [$cv cget $opt] }
            }
        }
        xview { }
        destroy {
            catch { tcllitehtml::_destroy $path }
            catch { interp alias {} $path {} }
            catch { $cv destroy }
        }
        default {
            $cv $sub {*}$args
        }
    }
}

package provide tcllitehtml 0.1.0
