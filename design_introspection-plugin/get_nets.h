#include "kernel/register.h"

USING_YOSYS_NAMESPACE

struct GetNets : public Pass {
	GetNets() : Pass("get_nets", "Print matching nets") {}

	void help() override;
	void execute(std::vector<std::string> args, RTLIL::Design* design) override;
};
