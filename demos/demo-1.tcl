set html [read [open seite.html r]]   ;# oder deine Test-Datei
# In demo-basic.tcl oder eigenem Test:
package require tcllitehtml
tcllitehtml::widget .w
pack .w -fill both -expand 1
.w load $html
