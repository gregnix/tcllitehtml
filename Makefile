# Makefile -- tcllitehtml

TCL_VER   ?= 8.6
TCL_INC   ?= /usr/include/tcl$(TCL_VER)
TK_INC    ?= /usr/include/tcl$(TCL_VER)
TCL_STUB  ?= tclstub$(TCL_VER)
TK_STUB   ?= tkstub$(TCL_VER)
TCLSH     ?= tclsh$(TCL_VER)
CMAKE     ?= cmake

ifeq ($(TCL_VER),9.0)
  TCL_INC  = /usr/include/tcl9.0
  TK_INC   = /usr/include/tcl9.0
  TCL_STUB = tclstub9.0
  TK_STUB  = tkstub9.0
endif

ifeq ($(SANITIZE),1)
  OPT = -g -O0 -fsanitize=address,undefined -fno-omit-frame-pointer
else
  OPT = -O2
endif

CBASE = -shared -fPIC -Wall -Wextra $(OPT) -std=c++17 \
        -I$(TCL_INC) -I$(TK_INC) -Isrc \
        -Ivendor/litehtml/include \
        -DUSE_TCL_STUBS -DUSE_TK_STUBS

ifeq ($(TCL_VER),9.0)
OUT            = lib/libtcllitehtml9.so
else
OUT            = lib/libtcllitehtml.so
endif
LITEHTML       = vendor/litehtml
LITEHTML_BUILD = vendor/litehtml-build
LITEHTML_LIB   = $(LITEHTML_BUILD)/liblitehtml.a
GUMBO_LIB      = $(LITEHTML_BUILD)/src/gumbo/libgumbo.a

.PHONY: all test clean litehtml litehtml-build verify demo-basic demo-table

all: check-vendor litehtml-build $(OUT)

check-vendor:
	@test -d $(LITEHTML)/include || \
	  (echo "FEHLT: vendor/litehtml/ — bitte 'make litehtml' ausführen" && exit 1)

litehtml-build: $(LITEHTML_LIB)

$(LITEHTML_LIB): $(LITEHTML)/CMakeLists.txt
	@mkdir -p $(LITEHTML_BUILD)
	@# Patch: resolve_color() Aufruf entfernen (verhindert Rekursions-Crash)
	@if grep -q "container->resolve_color" $(LITEHTML)/src/web_color.cpp; then \
	    sed -i "/container->resolve_color/d" $(LITEHTML)/src/web_color.cpp; \
	    echo "OK: litehtml web_color.cpp gepatcht"; \
	fi
	cd $(LITEHTML_BUILD) && $(CMAKE) \
	    -DCMAKE_BUILD_TYPE=Release \
	    -DBUILD_SHARED_LIBS=OFF \
	    -DLITEHTML_BUILD_TESTING=OFF \
	    -DCMAKE_CXX_FLAGS="-fPIC" \
	    -DCMAKE_C_FLAGS="-fPIC" \
	    ../litehtml
	$(MAKE) -C $(LITEHTML_BUILD) litehtml
	@echo "Built: $(LITEHTML_LIB)"

$(OUT): src/tcllitehtml.cpp src/container_tk.cpp src/tcllitehtml.h \
        src/container_tk.h $(LITEHTML_LIB)
	@mkdir -p lib
	g++ $(CBASE) \
	    -Wl,-rpath,'$$ORIGIN' \
	    -o $@ \
	    src/tcllitehtml.cpp src/container_tk.cpp \
	    $(LITEHTML_LIB) \
	    $(GUMBO_LIB) \
	    -l$(TCL_STUB) -l$(TK_STUB) -lm
	@echo "Built: $@"

litehtml:
	@mkdir -p vendor
	git clone --depth=1 https://github.com/litehtml/litehtml vendor/litehtml
	@echo "OK: vendor/litehtml/"

test: $(OUT)
	LD_LIBRARY_PATH=./lib wish tests/test-basic.tcl

verify:
	@test -d $(TCL_INC) && echo "OK: Tcl headers" || echo "FEHLT: tcl$(TCL_VER)-dev"
	@test -d vendor/litehtml && echo "OK: litehtml" || echo "FEHLT: make litehtml"
	@which cmake && echo "OK: cmake" || echo "FEHLT: cmake"

demo-basic: $(OUT)
	wish demos/demo-basic.tcl

demo-links: $(OUT)
	wish demos/demo-links.tcl

demo-css: $(OUT)
	wish demos/demo-css.tcl

demo-table: $(OUT)
	wish demos/demo-table.tcl

clean:
	rm -f $(OUT)
	rm -rf $(LITEHTML_BUILD)

# Tcl 9.0 Build — separate .so (ABI inkompatibel mit 8.6)
tcl9:
	$(MAKE) TCL_VER=9.0
	@echo "OK: lib/libtcllitehtml9.so"
	@echo "Test: LD_LIBRARY_PATH=./lib wish9.0 demos/demo-basic.tcl"

test9:
	$(MAKE) TCL_VER=9.0 test
