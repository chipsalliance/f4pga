#ifndef _GET_PINS_H_
#define _GET_PINS_H_

#include "get_cmd.h"

USING_YOSYS_NAMESPACE

struct GetPins : public GetCmd {
    GetPins() : GetCmd("get_pins", "Print matching pins") {}

   private:
    std::string TypeName() override;
    std::string SelectionType() override;
    SelectionObjects ExtractSelection(RTLIL::Design* design,
                                      const CommandArgs& args) override;
    void ExecuteSelection(RTLIL::Design* design,
                          const CommandArgs& args) override;
    void ExtractSingleSelection(SelectionObjects& objects,
                                RTLIL::Design* design,
                                const std::string& port_name,
                                const CommandArgs& args);
};

#endif  // GET_PINS_H_
