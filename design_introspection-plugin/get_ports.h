#ifndef _GET_PORTS_H_
#define _GET_PORTS_H_

#include "get_cmd.h"

USING_YOSYS_NAMESPACE

struct GetPorts : public GetCmd {
    GetPorts() : GetCmd("get_ports", "Print matching ports") {}

    std::string TypeName() override;
    std::string SelectionType() override;
    void execute(std::vector<std::string> args, RTLIL::Design* design) override;
};

#endif  // GET_PORTS_H_
