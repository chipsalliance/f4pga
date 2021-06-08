NAME = ql-dsp
SOURCES = ql-dsp.cc
include ../Makefile_plugin.common

pre-build:=$(shell python3 pmgen/pmgen.py -o ql-dsp-pm.h -p ql_dsp pmgen/ql_dsp.pmg)

clean:
	$(MAKE) -f ../Makefile_plugin.common $@
	rm -f *pm.h
