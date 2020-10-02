#ifndef _GET_CMD_H_
#define _GET_CMD_H_

#include "kernel/register.h"

USING_YOSYS_NAMESPACE

struct GetCmd : public Pass {
    using Filter = std::pair<std::string, std::string>;
    using Filters = std::vector<Filter>;
    using SelectionObjects = std::vector<std::string>;
    struct CommandArgs {
	Filters filters;
	bool is_quiet;
	SelectionObjects selection_objects;
    };

    GetCmd(const std::string& name, const std::string& description)
        : Pass(name, description) {}

    void help() override;
    void execute(std::vector<std::string> args, RTLIL::Design* design) override;

   protected:
    virtual std::string TypeName() = 0;
    virtual std::string SelectionType() = 0;
    CommandArgs ParseCommand(const std::vector<std::string>& args);
    virtual void ExtractSelection(Tcl_Obj*, RTLIL::Module*, const CommandArgs& args) {}
    virtual void ExecuteSelection(RTLIL::Design* design,
                                  const CommandArgs& args);
    virtual void PackSelectionToTcl(RTLIL::Design* design, const CommandArgs& args);
};

#endif  // GET_CMD_H_
