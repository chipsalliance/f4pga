TESTS = pll
include $(shell pwd)/../../Makefile_test.common

json_test = python compare_output_json.py --json $(1)/$(1).json --golden $(1)/$(1).golden.json

define json_update =
$(1)_update_json:
	python compare_output_json.py --json $(1)/$(1).json --golden $(1)/$(1).golden.json --update
endef

pll_verify = $(call json_test,pll) && test $$(grep "PASS" pll/pll.txt | wc -l) -eq 2

