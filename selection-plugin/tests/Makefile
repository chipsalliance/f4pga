TESTS = counter
.PHONY: $(TESTS)

counter_verify = $(call compare,counter,txt)

all: $(TESTS)
compare = diff $(1)/$(1).golden.$(2) $(1)/$(1).$(2)

define test_tpl =
$(1): $(1)/$(1).txt
	$$($(1)_verify)
	RETVAL=$$$$? ; \
	if [ $$$$RETVAL -eq 0 ]; then \
		echo "$(1) PASS"; \
		true; \
	else \
		echo "$(1) FAIL"; \
		false; \
	fi

$(1)/$(1).txt: $(1)/$(1).v
	cd $(1); \
	INPUT_SDC_FILE=$(1).input.sdc \
	OUTPUT_SDC_FILE=$(1).sdc \
	yosys -p "tcl $(1).tcl" -l yosys.log

endef

$(foreach test,$(TESTS),$(eval $(call test_tpl,$(test))))

clean:
	rm -rf $(foreach test,$(TESTS),$(test)/$(test).sdc $(test)/$(test).txt $(test)/yosys.log)
