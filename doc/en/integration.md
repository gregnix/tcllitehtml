# tcllitehtml Integration Guide

How to embed tcllitehtml in your Tcl/Tk application.

---

## Setup

### Option A: Direct load

```tcl
set _dir /path/to/tcllitehtml
set _ext [expr {$::tcl_platform(platform) eq "windows" ? ".dll" : ".so"}]
load [file join $_dir lib/libtcllitehtml${_ext}]
source [file join $_dir tcl/tcllitehtml/widget-0.1.tm]
```

### Option B: package require

```tcl
tcl::tm::path add /path/to/tcllitehtml/tcl
package require tcllitehtml
```

---

## Basic Pattern

```tcl
package require tcllitehtml

frame .f
pack .f -fill both -expand 1

scrollbar .f.sb -orient vertical -command {.f.html yview}
tcllitehtml::widget .f.html \
    -background white \
    -yscrollcommand {.f.sb set} \
    -openurl 1 \
    -command on_link_click
pack .f.sb   -side right -fill y
pack .f.html -side left  -fill both -expand 1

proc on_link_click {url} {
    if {[string match "http*" $url]} {
        # open in system browser
        if {$::tcl_platform(platform) eq "windows"} {
            exec cmd /c start $url &
        } else {
            exec xdg-open $url &
        }
    } elseif {[string match "app:*" $url]} {
        # internal navigation
        set page [string range $url 4 end]
        load_page $page
    }
}

# Load content
.f.html load {<h1>Hello</h1><p>World</p>}
.f.html load -file /path/to/help.html
```

---

## Keyboard Bindings

```tcl
bind .f.html <Button-1>    { focus %W }
bind .f.html <Control-Home> { .f.html yview moveto 0.0 }
bind .f.html <Control-End>  { .f.html yview moveto 1.0 }
bind .f.html <Prior>        { .f.html yview scroll -1 pages }
bind .f.html <Next>         { .f.html yview scroll  1 pages }
bind .f.html <Up>           { .f.html yview scroll -3 units }
bind .f.html <Down>         { .f.html yview scroll  3 units }
```

---

## Generating HTML

```tcl
# Safe HTML escaping
proc html_escape {text} {
    string map {& &amp; < &lt; > &gt; \" &quot;} $text
}

# Generate a table
proc html_table {headers rows} {
    set h "<table><tr>"
    foreach col $headers {
        append h "<th>[html_escape $col]</th>"
    }
    append h "</tr>"
    foreach row $rows {
        append h "<tr>"
        foreach cell $row {
            append h "<td>[html_escape $cell]</td>"
        }
        append h "</tr>"
    }
    append h "</table>"
    return $h
}

# Usage
set html [html_table {Name Value} {{alpha 1} {beta 2}}]
.f.html load "<html><body>$html</body></html>"
```

---

## Dynamic Images

```tcl
# Inject a Tk photo image for a URL
proc embed_image {widget url photo} {
    tcllitehtml::_setimage $widget $url $photo
}

# Example: generated chart image
image create photo myChart -width 400 -height 200
# ... draw chart on myChart ...
embed_image .f.html "app://chart" myChart
.f.html load {<html><body>
    <img src="app://chart" width="400" height="200">
</body></html>}
```

---

## CSS Themes

```tcl
proc make_html {body_html {css ""}} {
    if {$css eq ""} {
        set css {
            body  { font-family: sans-serif; font-size: 13px;
                    margin: 15px; background: white; }
            h1    { color: #2040a0; border-bottom: 1px solid #ccc; }
            h2    { color: #4060c0; }
            a     { color: #2040a0; }
            code  { background: #f0f0f0; padding: 2px 4px; }
            pre   { background: #f0f0f0; padding: 8px;
                    border-left: 3px solid #999; }
            table { border-collapse: collapse; width: 100%; }
            th    { background: #2040a0; color: white; padding: 4px 8px; }
            td    { border: 1px solid #ccc; padding: 3px 8px; }
        }
    }
    return "<html><head><style>$css</style></head><body>$body_html</body></html>"
}

.f.html load [make_html "<h1>Title</h1><p>Content</p>"]
```

---

## External CSS (HTTP)

When loading HTML from a URL, set the base URL first so relative
CSS and image references resolve correctly:

```tcl
tcllitehtml::_setbaseurl .f.html $url
.f.html load $html_content
```
