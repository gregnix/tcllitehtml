#!/usr/bin/env bash
# install-linux.sh -- Kopiert tcllitehtml ins user-lokale Tcl-Lib-Verzeichnis.
#
# Voraussetzung: vorher 'make' (Tcl 8.6) und/oder 'make tcl9' (Tcl 9.0).
# Aufruf aus dem Repo-Wurzelverzeichnis: ./install-linux.sh

set -e

PREFIX="${PREFIX:-$HOME/lib/tcltk}"
DEST="$PREFIX/tcllitehtml"

# Pfad zur angepassten pkgIndex.tcl (Option B mit Windows-Preload-Code,
# funktioniert auch unter Linux unverändert).
# Wenn die Datei direkt neben diesem Script liegt: einfach nutzen.
PKGINDEX_SRC="$(dirname "$0")/tcllitehtml-pkgIndex-flat-b.tcl"
if [ ! -f "$PKGINDEX_SRC" ]; then
    # Fallback: aus Standard-Repo-Pfad
    PKGINDEX_SRC="tcl/tcllitehtml/pkgIndex.tcl"
    echo "WARNUNG: nutze Original pkgIndex.tcl ($PKGINDEX_SRC),"
    echo "         relative ../../lib/-Pfade werden brechen!"
fi

mkdir -p "$DEST"

# Tcl-Modul
cp tcl/tcllitehtml/widget-0.1.tm "$DEST/"

# angepasste pkgIndex.tcl
cp "$PKGINDEX_SRC" "$DEST/pkgIndex.tcl"

# Libraries (was gebaut wurde)
if [ -f lib/libtcllitehtml.so ]; then
    cp lib/libtcllitehtml.so "$DEST/"
    echo "  Tcl 8.6: $DEST/libtcllitehtml.so"
fi
if [ -f lib/libtcllitehtml9.so ]; then
    cp lib/libtcllitehtml9.so "$DEST/"
    echo "  Tcl 9.0: $DEST/libtcllitehtml9.so"
fi
if [ ! -f "$DEST/libtcllitehtml.so" ] && [ ! -f "$DEST/libtcllitehtml9.so" ]; then
    echo "FEHLER: keine .so gefunden in lib/." >&2
    echo "        Bitte 'make' und/oder 'make tcl9' ausführen." >&2
    exit 1
fi

echo
echo "Installation in $DEST abgeschlossen."
echo
echo "Damit Tcl das Paket findet, einmalig in ~/.bashrc:"
echo "  export TCLLIBPATH=\"$PREFIX\""
echo
echo "Verifizieren:"
echo "  tclsh   -c 'package require tcllitehtml; puts [package present tcllitehtml]'"
echo "  tclsh90 -c 'package require tcllitehtml; puts [package present tcllitehtml]'"
