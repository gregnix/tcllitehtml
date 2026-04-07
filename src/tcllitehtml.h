/* tcllitehtml.h -- tcllitehtml: HTML widget for Tcl/Tk
 *
 * WICHTIG: litehtml vor Tk includen (False/True Makro-Konflikt)
 */
#ifndef TCLLITEHTML_H
#define TCLLITEHTML_H

/* litehtml zuerst */
#include <litehtml.h>

/* Tk-Makro-Konflikte bereinigen */
#ifdef False
#  undef False
#endif
#ifdef True
#  undef True
#endif
#ifdef Bool
#  undef Bool
#endif
#ifdef None
#  undef None
#endif

#include <tcl.h>
#include <tk.h>

#define TCLLITEHTML_VERSION "0.1.0"

#ifdef __cplusplus
extern "C" {
#endif

DLLEXPORT int Tcllitehtml_Init(Tcl_Interp *interp);

#ifdef __cplusplus
}
#endif

#endif /* TCLLITEHTML_H */
