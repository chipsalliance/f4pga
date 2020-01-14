TESTS = counter

all: $(TESTS)

define test_tpl =
$(1): $(1).json
	@python compare_output_json.py --json $$< --golden $(1)_golden.json; \
	RETVAL=$$$$? ; \
	if [ $$$$RETVAL -eq 0 ]; then \
		echo "$(1) PASS"; \
		true; \
	else \
		echo "$(1) FAIL"; \
		false; \
	fi

$(1).json: $(1).v
	PART_JSON=xc7a35tcsg324-1.json \
	OUT_JSON=$(1).json \
	INPUT_XDC_FILE=$(1).xdc \
	yosys -p "tcl synth.tcl" $$< -l yosys.log

update_$(1): $(1).json
	@python compare_output_json.py --json $$< --golden $(1)_golden.json --update

endef

$(foreach test,$(TESTS),$(eval $(call test_tpl,$(test))))

update: $(foreach test,$(TESTS),update_$(test))


clean:
	rm -rf *.log $(foreach test,$(TESTS),$(test).json)
