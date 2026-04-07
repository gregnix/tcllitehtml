# pkgIndex.tcl -- tcllitehtml package index
# Lädt die passende .so/.dll je nach Tcl-Version und Plattform

package ifneeded tcllitehtml 0.1.0 {
    set _dir [file dirname [info script]]
    if {$::tcl_platform(platform) eq "windows"} {
        set _lib [file join $_dir ../../lib/libtcllitehtml.dll]
    } elseif {[package vsatisfies [package provide Tcl] 9.0-]} {
        set _lib9 [file join $_dir ../../lib/libtcllitehtml9.so]
        set _lib  [file join $_dir ../../lib/libtcllitehtml.so]
        if {[file exists $_lib9]} { set _lib $_lib9 }
    } else {
        set _lib [file join $_dir ../../lib/libtcllitehtml.so]
    }
    if {[file exists $_lib]} {
        load $_lib
    } else {
        error "tcllitehtml: $_lib nicht gefunden.\
               Bitte 'make' (Tcl 8.6) oder 'make tcl9' (Tcl 9.0) ausführen."
    }
    source [file join $_dir widget-0.1.tm]
}
