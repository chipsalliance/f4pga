#ifndef _GET_CMD_H_
#define _GET_CMD_H_

#include "kernel/register.h"

USING_YOSYS_NAMESPACE

struct GetCmd : public Pass {
	GetCmd(const std::string& name, const std::string& description) : Pass(name, description) {}

        void help() override;
	void execute(std::vector<std::string> args, RTLIL::Design* design) override;
	virtual std::string TypeName() = 0;
};

#endif  // GET_CMD_H_
