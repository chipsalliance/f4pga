TESTS = sdiomux ckpad

all: clean $(addsuffix /ok,$(TESTS))

clean:
	@find . -name "ok" | xargs rm -rf

sdiomux/ok:
	cd sdiomux && $(MAKE) test
ckpad/ok:
	cd ckpad && $(MAKE) test

.PHONY: all clean
