#include "kernel/register.h"

USING_YOSYS_NAMESPACE

struct GetPorts : public Pass {
	GetPorts() : Pass("get_ports", "Print matching ports") {}

	void help() override;

	void execute(std::vector<std::string> args, RTLIL::Design* design) override;
};
