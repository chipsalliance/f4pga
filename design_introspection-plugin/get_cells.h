#ifndef _GET_CELLS_H_
#define _GET_CELLS_H_

#include "get_cmd.h"

USING_YOSYS_NAMESPACE

struct GetCells : public GetCmd {
    GetCells() : GetCmd("get_cells", "Print matching cells") {}

    std::string TypeName() override;
    std::string SelectionType() override;
    SelectionObjects ExtractSelection(RTLIL::Design* design,
                          const CommandArgs& args) override;
};

#endif  // GET_CELLS_H_
