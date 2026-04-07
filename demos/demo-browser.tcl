#!/usr/bin/env wish
# demo-browser.tcl -- Mini-Browser mit tcllitehtml
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

package require http
package require tls
http::register https 443 [list ::tls::socket -tls1.2 1]

wm title . "tcllitehtml Mini-Browser"
wm geometry . 1000x750
bind . <Escape> { destroy . }

# --- Navigationszustand ---
set ::history {}
set ::history_pos -1
set ::current_url ""
set ::base_url ""

# --- Toolbar ---
frame .tb -relief raised -bd 1
pack .tb -fill x

button .tb.back    -text "◀"  -width 3 -command nav_back
button .tb.forward -text "▶"  -width 3 -command nav_forward
button .tb.reload  -text "⟳"  -width 3 -command { nav_go $::current_url }
entry  .tb.url     -textvariable ::current_url -font {Sans 11}
button .tb.go      -text "Los"  -command { nav_go $::current_url }
label  .tb.status  -text "Bereit" -anchor w -fg #444

pack .tb.back .tb.forward .tb.reload -side left -padx 2 -pady 3
pack .tb.url  -side left -fill x -expand 1 -padx 4 -pady 3
pack .tb.go -side left -padx 2 -pady 3
pack .tb.status -side left -padx 8 -fill x -expand 0

bind .tb.url <Return> { nav_go $::current_url }

# --- HTML-Widget ---
frame .f
pack .f -fill both -expand 1
scrollbar .f.sb -orient vertical -command {.f.html yview}
tcllitehtml::widget .f.html \
    -background white \
    -yscrollcommand {.f.sb set} \
    -command on_link_click
pack .f.sb   -side right -fill y
pack .f.html -side left  -fill both -expand 1


# --- Navigation ---
proc nav_go {url} {
    if {$url eq ""} return
    # http:// ergänzen wenn nötig
    if {![string match "http*" $url]} {
        set url "https://$url"
        set ::current_url $url
    }
    .tb.status configure -text "Lade $url ..."
    update
    if {[catch { fetch_url $url } err]} {
        .tb.status configure -text "Fehler: $err"
        .f.html load "<html><body><h2>Fehler</h2><p>$err</p></body></html>"
    }
}

proc fetch_url {url} {
    set token [http::geturl $url \
        -timeout 15000 \
        -headers {Accept-Encoding identity} \
    ]
    set status [http::status $token]
    set ncode  [http::ncode  $token]
    set meta   [http::meta   $token]

    # Redirect folgen
    if {$ncode in {301 302 303 307 308}} {
        set loc [dict get $meta Location]
        http::cleanup $token
        # Relative Redirect
        if {![string match "http*" $loc]} {
            set loc [url_resolve $url $loc]
        }
        set ::current_url $loc
        fetch_url $loc
        return
    }

    set data [http::data $token]
    http::cleanup $token

    # Encoding erkennen
    set content_type ""
    catch { set content_type [dict get $meta Content-Type] }
    set enc utf-8
    if {[regexp {charset=([^\s;]+)} $content_type -> cs]} {
        set enc [string tolower $cs]
        catch { set enc [string map {iso-8859-1 iso8859-1 windows-1252 cp1252} $enc] }
    }
    catch { set data [encoding convertfrom $enc $data] }

    # Base URL setzen
    set ::base_url $url
    set ::current_url $url

    # History
    global history history_pos
    if {$history_pos < 0 || [lindex $history $history_pos] ne $url} {
        set history [lrange $history 0 $history_pos]
        lappend history $url
        set history_pos [expr {[llength $history]-1}]
    }

    tcllitehtml::_setbaseurl .f.html $url
    .f.html load $data
    wm title . "tcllitehtml — [url_title $url]"
    .tb.status configure -text "OK: $url"
}

proc on_link_click {url} {
    # Relative URLs auflösen
    if {![string match "http*" $url] && ![string match "#*" $url]} {
        set url [url_resolve $::base_url $url]
    }
    if {[string match "#*" $url]} {
        .tb.status configure -text "Anker: $url (nicht unterstützt)"
        return
    }
    set ::current_url $url
    nav_go $url
}

proc nav_back {} {
    global history history_pos
    if {$history_pos <= 0} return
    incr history_pos -1
    set ::current_url [lindex $history $history_pos]
    nav_go $::current_url
}

proc nav_forward {} {
    global history history_pos
    if {$history_pos >= [llength $history]-1} return
    incr history_pos 1
    set ::current_url [lindex $history $history_pos]
    nav_go $::current_url
}

proc url_resolve {base relative} {
    # Einfache URL-Auflösung
    if {[string match "http*" $relative]} { return $relative }
    if {[string match "//*" $relative]} {
        regexp {^(https?:)} $base -> scheme
        return "${scheme}${relative}"
    }
    if {[string match "/*" $relative]} {
        regexp {^(https?://[^/]+)} $base -> origin
        return "${origin}${relative}"
    }
    # Relativ zur aktuellen Seite
    set base [regsub {/[^/]*$} $base ""]
    return "${base}/${relative}"
}

proc url_title {url} {
    regsub {^https?://} $url "" t
    set t [string range $t 0 59]
    return $t
}

# --- Startseite laden ---
set ::current_url "https://www.tcl-lang.org/man/tcl8.6/"
nav_go $::current_url
