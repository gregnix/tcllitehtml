# pkgIndex.tcl -- tcllitehtml (flat install layout, cross-platform)
#
# Erwartete Dateien IM SELBEN VERZEICHNIS wie diese Datei:
#   Linux Tcl 8.6:  libtcllitehtml.so
#   Linux Tcl 9.0:  libtcllitehtml9.so  (Fallback auf .so wenn fehlt)
#   Windows:        libtcllitehtml.dll
#                   + libstdc++-6.dll, libgcc_s_seh-1.dll, libwinpthread-1.dll
#                     (MinGW-Runtime, in den meisten BAWT-Trees schon im PATH)
#   widget-0.1.tm   (immer)

package ifneeded tcllitehtml 0.1.0 [list apply {{dir} {
    if {$::tcl_platform(platform) eq "windows"} {
        # PATH temporär augmentieren, damit Windows-DLL-Loader Geschwister
        # findet (libstdc++ usw. neben libtcllitehtml.dll)
        set _oldpath $::env(PATH)
        set ::env(PATH) "$dir;$_oldpath"

        # Abhängigkeiten explizit vorladen, falls daneben liegend.
        # Reihenfolge wichtig: erst Compiler-Runtime, dann höhere Layer.
        foreach _dep {
            libwinpthread-1.dll
            libgcc_s_seh-1.dll
            libstdc++-6.dll
        } {
            set _p [file join $dir $_dep]
            if {[file exists $_p]} { catch {load $_p} }
        }

        set _lib [file join $dir libtcllitehtml.dll]
    } elseif {[package vsatisfies [package provide Tcl] 9.0-]} {
        set _lib9 [file join $dir libtcllitehtml9.so]
        set _lib  [file join $dir libtcllitehtml.so]
        if {[file exists $_lib9]} { set _lib $_lib9 }
    } else {
        set _lib [file join $dir libtcllitehtml.so]
    }

    if {[file exists $_lib]} {
        load $_lib
    } else {
        error "tcllitehtml: $_lib nicht gefunden.\
               Bitte 'make' (Linux) / 'build-win.bat' (Windows) ausführen\
               und Binary nach diesem Verzeichnis kopieren."
    }

    if {$::tcl_platform(platform) eq "windows"} {
        set ::env(PATH) $_oldpath
    }

    source [file join $dir widget-0.1.tm]
}} $dir]
