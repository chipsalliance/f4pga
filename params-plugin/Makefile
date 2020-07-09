CXX = $(shell yosys-config --cxx)
CXXFLAGS = $(shell yosys-config --cxxflags)
LDFLAGS = $(shell yosys-config --ldflags)
LDLIBS = $(shell yosys-config --ldlibs)
PLUGINS_DIR = $(shell yosys-config --datdir)/plugins

OBJS = params.o

params.so: $(OBJS)
	$(CXX) $(CXXFLAGS) $(LDFLAGS) -shared -o $@ $^ $(LDLIBS)

install_plugin: params.so
	mkdir -p $(PLUGINS_DIR)
	cp $< $(PLUGINS_DIR)/$<

test: install_plugin
	$(MAKE) -C tests all

.PHONY: install
install: install_plugin

clean:
	rm -f *.d *.o params.so
	$(MAKE) -C tests clean

