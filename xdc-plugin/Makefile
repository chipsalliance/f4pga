CXX = $(shell yosys-config --cxx)
CXXFLAGS = $(shell yosys-config --cxxflags)
LDFLAGS = $(shell yosys-config --ldflags)
LDLIBS = $(shell yosys-config --ldlibs)
PLUGINS_DIR = $(shell yosys-config --datdir)/plugins

OBJS = xdc.o
VERILOG_MODULES = BANK.v

xdc.so: $(OBJS)
	$(CXX) $(CXXFLAGS) $(LDFLAGS) -shared -o $@ $^ $(LDLIBS)

install_plugin: xdc.so
	mkdir -p $(PLUGINS_DIR)
	cp $< $(PLUGINS_DIR)/$<

install_modules: $(VERILOG_MODULES)
	mkdir -p $(PLUGINS_DIR)/fasm_extra_modules/
	cp $< $(PLUGINS_DIR)/fasm_extra_modules/$<

test: install_plugin install_modules
	$(MAKE) -C tests all

.PHONY: install
install: install_modules install_plugin

clean:
	rm -f *.d *.o xdc.so

