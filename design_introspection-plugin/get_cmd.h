#ifndef _GET_CMD_H_
#define _GET_CMD_H_

#include "kernel/register.h"

USING_YOSYS_NAMESPACE

struct GetCmd : public Pass {
    using Filter = std::pair<std::string, std::string>;
    using Filters = std::vector<Filter>;

    GetCmd(const std::string& name, const std::string& description)
        : Pass(name, description) {}

    void help() override;
    void execute(std::vector<std::string> args, RTLIL::Design* design) override;
    virtual std::string TypeName() = 0;
    virtual std::string SelectionType() = 0;
    virtual void ExtractSelection(Tcl_Obj*, RTLIL::Module*, Filters&, bool) = 0;
};

#endif  // GET_CMD_H_
