#ifndef _GET_NETS_H_
#define _GET_NETS_H_

#include "get_cmd.h"

USING_YOSYS_NAMESPACE

struct GetNets : public GetCmd {
    GetNets() : GetCmd("get_nets", "Print matching nets") {}

    std::string TypeName() override;
    std::string SelectionType() override;
    SelectionObjects ExtractSelection(RTLIL::Design* design,
                                      const CommandArgs& args) override;
};

#endif  // GET_NETS_H_
