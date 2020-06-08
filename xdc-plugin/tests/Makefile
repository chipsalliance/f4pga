# counter - basic test for IOSTANDARD, SLEW, DRIVE, IN_TERM properties
# port_indexes - like counter but bus port indices are passes without curly braces
# io_loc_pairs - test for LOC property being set on IOBUFs as the IO_LOC_PAIRS parameter
# minilitex_ddr_arty - litex design with more types of IOBUFS including differential

TESTS = counter \
	port_indexes \
	io_loc_pairs \
	minilitex_ddr_arty

counter_verify = $(call compare_json,counter)
port_indexes_verify = $(call compare_json,port_indexes) && test $$(grep "'unknown' proc command handler" port_indexes/port_indexes.txt | wc -l) -eq 2
io_loc_pairs_verify = $(call compare_json,io_loc_pairs)
minilitex_ddr_arty_verify = $(call compare_json,minilitex_ddr_arty)

all: $(TESTS)

compare_json = python compare_output_json.py --json $(1)/$(1).json --golden $(1)/$(1)_golden.json

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
	@python compare_output_json.py --json $$< --golden $(1)/$(1)_golden.json --update

endef

$(foreach test,$(TESTS),$(eval $(call test_tpl,$(test))))

update: $(foreach test,$(TESTS),update_$(test))


clean:
	rm -rf $(foreach test,$(TESTS),$(test)/$(test).json $(test)/$(test).eblif $(test)/$(test).txt $(test)/yosys.log)
