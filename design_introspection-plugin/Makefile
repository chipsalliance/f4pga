CXX = $(shell yosys-config --cxx)
CXXFLAGS = $(shell yosys-config --cxxflags)
LDFLAGS = $(shell yosys-config --ldflags)
LDLIBS = $(shell yosys-config --ldlibs)
PLUGINS_DIR = $(shell yosys-config --datdir)/plugins

NAME = design_introspection
OBJS = $(NAME).o get_cmd.o get_nets.o get_ports.o get_cells.o

$(NAME).so: $(OBJS)
	$(CXX) $(CXXFLAGS) $(LDFLAGS) -shared -o $@ $^ $(LDLIBS)

install_plugin: $(NAME).so
	mkdir -p $(PLUGINS_DIR)
	cp $< $(PLUGINS_DIR)/$<

test:
	$(MAKE) -C tests all

.PHONY: install
install: install_plugin

clean:
	rm -f *.d *.o *.so
	$(MAKE) -C tests clean

