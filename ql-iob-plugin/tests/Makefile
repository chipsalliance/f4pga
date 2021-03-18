TESTS = sdiomux ckpad

all: clean $(addsuffix /ok,$(TESTS))

clean:
	@find . -name "ok" | xargs rm -rf

sdiomux/ok:
	@$(MAKE) -C sdiomux test
ckpad/ok:
	@$(MAKE) -C ckpad test

.PHONY: all clean
