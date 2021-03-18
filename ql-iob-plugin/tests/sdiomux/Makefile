# TODO: Integrate this in the Makefile_test.command environment ?
test:
	yosys -s script.ys -q -q -l $@.log
	@printf "Test %-18s \e[32mPASSED\e[0m @ %s\n" $@ $(CURDIR);
	@touch ok
