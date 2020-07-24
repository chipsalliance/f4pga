CXX = $(shell yosys-config --cxx)
CXXFLAGS = $(shell yosys-config --cxxflags)
LDFLAGS = $(shell yosys-config --ldflags)
LDLIBS = $(shell yosys-config --ldlibs)
PLUGINS_DIR = $(shell yosys-config --datdir)/plugins

NAME = get_count
OBJS = $(NAME).o

$(NAME).so: $(OBJS)
	$(CXX) $(CXXFLAGS) $(LDFLAGS) -shared -o $@ $^ $(LDLIBS)

.PHONY: install test

install: test
	mkdir -p $(PLUGINS_DIR)
	cp $(NAME).so $(PLUGINS_DIR)/$(NAME).so

test: $(NAME).so
	$(MAKE) -C tests all

clean:
	rm -f *.d *.o *.so
	$(MAKE) -C tests clean
