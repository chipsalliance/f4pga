NAME = uhdm
SOURCES = UhdmAst.cc \
	  uhdmastfrontend.cc \
	  uhdmastreport.cc \
	  vpivisitor.cc

include ../Makefile_plugin.common

CPPFLAGS += -std=c++14 -I${UHDM_INSTALL_DIR}/include/uhdm \
			-I${UHDM_INSTALL_DIR}/include/uhdm/include \
			-I${UHDM_INSTALL_DIR}/include/uhdm/headers

CXXFLAGS += -Wno-inconsistent-missing-override
LDFLAGS += -L${UHDM_INSTALL_DIR}/lib/uhdm -L${UHDM_INSTALL_DIR}/lib
LDLIBS += -luhdm -lcapnp -lkj -ldl -lutil -lm -lrt -lpthread
