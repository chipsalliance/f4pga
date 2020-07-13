TESTS = pll

pll_verify = $(call compare_json,pll) && test $$(grep "PASS" pll/params.txt | wc -l) -eq 2

all: $(TESTS)

compare_json = python compare_output_json.py --json $(1)/$(1).json --golden $(1)/$(1).golden.json

define test_tpl =
$(1): $(1)/$(1).json
	$$($(1)_verify)
	RETVAL=$$$$? ; \
	if [ $$$$RETVAL -eq 0 ]; then \
		echo "$(1) PASS"; \
		true; \
	else \
		echo "$(1) FAIL"; \
		false; \
	fi

$(1)/$(1).json: $(1)/$(1).v
	cd $(1); \
	PART_JSON=../xc7a35tcsg324-1.json \
	OUT_JSON=$(1).json \
	INPUT_XDC_FILE=$(1).xdc \
	yosys -p "tcl $(1).tcl" $(1).v -l yosys.log

update_$(1): $(1)/$(1).json
	@python compare_output_json.py --json $$< --golden $(1)/$(1).golden.json --update

endef

$(foreach test,$(TESTS),$(eval $(call test_tpl,$(test))))

update: $(foreach test,$(TESTS),update_$(test))


clean:
	rm -rf $(foreach test,$(TESTS),$(test)/$(test).json $(test)/$(test).eblif $(test)/$(test).txt $(test)/yosys.log)
