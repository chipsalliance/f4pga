CXX = $(shell yosys-config --cxx)
CXXFLAGS = $(shell yosys-config --cxxflags)
LDFLAGS = $(shell yosys-config --ldflags)
LDLIBS = $(shell yosys-config --ldlibs)
PLUGINS_DIR = $(shell yosys-config --datdir)/plugins

OBJS = buffers.o clocks.o propagation.o sdc.o sdc_writer.o set_false_path.o

sdc.so: $(OBJS)
	$(CXX) $(CXXFLAGS) $(LDFLAGS) -shared -o $@ $^ $(LDLIBS)

install_plugin: sdc.so
	mkdir -p $(PLUGINS_DIR)
	cp $< $(PLUGINS_DIR)/$<

test:
	$(MAKE) -C tests all

.PHONY: install
install: install_plugin

clean:
	rm -f *.d *.o *.so
	$(MAKE) -C tests clean

