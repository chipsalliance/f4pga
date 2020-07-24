TESTS = $(subst /, ,$(wildcard */))

all: $(addsuffix /ok,$(TESTS))

clean:
	@find . -name "ok" | xargs rm -rf

define maketest =
$1/ok:
	cd $1 && $(MAKE) test
endef

$(foreach _,${TESTS},$(eval $(call maketest,$_)))

.PHONY: all clean
