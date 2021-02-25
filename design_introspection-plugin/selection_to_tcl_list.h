/*
 *  yosys -- Yosys Open SYnthesis Suite
 *
 *  Copyright (C) 2012  Clifford Wolf <clifford@clifford.at>
 *  Copyright (C) 2020  The Symbiflow Authors
 *
 *  Permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */
#ifndef _SELECTION_TO_TCL_LIST_H_
#define _SELECTION_TO_TCL_LIST_H_

#include "kernel/register.h"

USING_YOSYS_NAMESPACE

struct SelectionToTclList : public Pass {
    SelectionToTclList() : Pass("selection_to_tcl_list", "Extract selection to TCL list") {}

    void help() override;
    void execute(std::vector<std::string> args, RTLIL::Design *design) override;

  private:
    void AddObjectNameToTclList(RTLIL::IdString &module, RTLIL::IdString &object, Tcl_Obj *tcl_list);
};

#endif // SELECTION_TO_TCL_LIST_H_
