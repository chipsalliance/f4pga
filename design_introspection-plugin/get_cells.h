#ifndef _GET_CELLS_H_
#define _GET_CELLS_H_

#include "get_cmd.h"

USING_YOSYS_NAMESPACE

struct GetCells : public GetCmd {
    GetCells() : GetCmd("get_cells", "Print matching cells") {}

    std::string TypeName() override;
    std::string SelectionType() override;
    void ExtractSelection(Tcl_Obj* tcl_list, RTLIL::Module* module,
                          Filters& filters, bool is_quiet) override;
};

#endif  // GET_CELLS_H_
