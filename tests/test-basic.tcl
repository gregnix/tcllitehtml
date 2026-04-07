# test-basic.tcl -- tcllitehtml Grundtests
# Aufruf: make test   (= LD_LIBRARY_PATH=./lib wish tests/test-basic.tcl)

package require tcltest 2.2
namespace import ::tcltest::*

set _dir [file normalize [file dirname [info script]]]
if {$::tcl_platform(platform) eq "windows"} {
    set _so [file join $_dir ../lib/libtcllitehtml.dll]
} elseif {[package vsatisfies [package provide Tcl] 9.0-]} {
    set _so9 [file join $_dir ../lib/libtcllitehtml9.so]
    set _so  [file join $_dir ../lib/libtcllitehtml.so]
    if {[file exists $_so9]} { set _so $_so9 }
} else {
    set _so [file join $_dir ../lib/libtcllitehtml.so]
}

if {[file exists $_so]} {
    load $_so
} else {
    puts "FEHLT: $_so — bitte 'make' ausführen"
    exit 1
}
source [file join $_dir ../tcl/tcllitehtml/widget-0.1.tm]

proc with_widget {path args script} {
    tcllitehtml::widget $path -width 400 -height 300 {*}$args
    set result [uplevel 1 $script]
    catch {destroy $path}
    return $result
}

# ================================================================
# 1. Package
# ================================================================

test pkg-1.0 {Package vorhanden} {
    package present tcllitehtml
} {0.1.0}

# ================================================================
# 2. Widget erzeugen
# ================================================================

test widget-2.0 {Widget erzeugt Tk-Fenster} {
    with_widget .t1 {} { winfo exists .t1 }
} {1}

test widget-2.1 {Widget-Pfad zurückgegeben} {
    set w [tcllitehtml::widget .t2 -width 400 -height 300]
    set r [expr {$w eq ".t2"}]
    catch {destroy .t2}
    set r
} {1}

test widget-2.2 {-width Option} {
    with_widget .t3 {-width 500} { .t3 cget -width }
} {500}

test widget-2.3 {-background Option} {
    with_widget .t4 {-background #ff0000} { .t4 cget -background }
} {#ff0000}

# ================================================================
# 3. HTML laden
# ================================================================

test load-3.0 {Einfaches HTML} {
    with_widget .t5 {} {
        .t5 load {<h1>Test</h1><p>Absatz</p>}
        expr {1}
    }
} {1}

test load-3.1 {Tabelle} {
    with_widget .t6 {} {
        .t6 load {<table><tr><th>A</th></tr><tr><td>1</td></tr></table>}
        expr {1}
    }
} {1}

test load-3.2 {Tabelle colspan} {
    with_widget .t7 {} {
        .t7 load {<table><tr><th colspan="2">Titel</th></tr>
            <tr><td>A</td><td>B</td></tr></table>}
        expr {1}
    }
} {1}

test load-3.3 {Tabelle rowspan} {
    with_widget .t8 {} {
        .t8 load {<table>
            <tr><th rowspan="2">R</th><td>1</td></tr>
            <tr><td>2</td></tr></table>}
        expr {1}
    }
} {1}

test load-3.4 {HTML mit CSS} {
    with_widget .t9 {} {
        .t9 load {<html><head><style>
            body { font-family: Sans; font-size: 14px; }
            h1 { color: #2040a0; }
            </style></head><body>
            <h1>Test</h1><p>Text</p>
            </body></html>}
        expr {1}
    }
} {1}

test load-3.5 {-file Option} {
    set f [open /tmp/test-tcllitehtml.html w]
    puts $f {<html><body><h1>Test</h1></body></html>}
    close $f
    with_widget .t10 {} {
        .t10 load -file /tmp/test-tcllitehtml.html
        expr {1}
    }
} {1}

# ================================================================
# 4. Scrolling
# ================================================================

test scroll-4.0 {yview scroll} {
    with_widget .ts1 {} {
        .ts1 load {<p>Text</p>}
        .ts1 yview scroll 1 units
        expr {1}
    }
} {1}

test scroll-4.1 {_info doc_height} {
    with_widget .ts2 {} {
        .ts2 load {<p>Ein langer Text.</p>}
        set h [tcllitehtml::_info .ts2 doc_height]
        expr {$h > 0}
    }
} {1}

test scroll-4.2 {_info scroll_y} {
    with_widget .ts3 {} {
        .ts3 load {<p>Text</p>}
        expr {[tcllitehtml::_info .ts3 scroll_y] == 0}
    }
} {1}

# ================================================================
# 5. Fehlerbehandlung
# ================================================================

test error-5.0 {Leeres HTML} {
    with_widget .te1 {} {
        .te1 load {}
        expr {1}
    }
} {1}

test error-5.1 {Ungültige Datei} {
    with_widget .te2 {} {
        catch {.te2 load -file /tmp/existiert-nicht-xyz.html}
    }
} {1}

test error-5.2 {_info unbekannter Key} {
    with_widget .te3 {} {
        catch {tcllitehtml::_info .te3 unbekannt}
    }
} {1}

# ================================================================
# 6. Link-Callback
# ================================================================

test link-6.0 {-command Option} {
    with_widget .tl1 {-command {apply {{url} {}}}} {
        .tl1 load {<a href="test://link">Link</a>}
        expr {1}
    }
} {1}

# ================================================================
cleanupTests
