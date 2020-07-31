/*
 *  yosys -- Yosys Open SYnthesis Suite
 *
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
#ifndef _PROPAGATION_H_
#define _PROPAGATION_H_

#include <cassert>
#include "kernel/rtlil.h"
#include "kernel/register.h"
#include "clocks.h"

USING_YOSYS_NAMESPACE

class Propagation {
    public:
	Propagation(RTLIL::Design* design)
	    : design_(design) {}

	virtual void Run(Clocks& clocks) = 0;

    public:
	RTLIL::Design* design_;
};

class NaturalPropagation : public Propagation {
    public:
	NaturalPropagation(RTLIL::Design* design, Pass* pass)
	    : Propagation(design)
       	    , pass_(pass) {}

	void Run(Clocks& clocks) override {
	    clocks.Propagate(this);
	}
	std::vector<RTLIL::Wire*> SelectAliases(RTLIL::Wire* wire) {
	    RTLIL::Module* top_module = design_->top_module();
	    assert(top_module);
	    std::vector<RTLIL::Wire*> selected_wires;
	    pass_->extra_args(std::vector<std::string>{top_module->name.str() + "/w:" + wire->name.str(), "%a"}, 0, design_);
	    for (auto module : design_->selected_modules()) {
		//log("Wires selected in module %s:\n", module->name.c_str());
		for (auto wire : module->selected_wires()) {
		    //log("%s\n", wire->name.c_str());
		    selected_wires.push_back(wire);
		}
	    }
	    return selected_wires;
	}

    private:
	Pass* pass_;
};

class BufferPropagation : public Propagation {
    public:
	BufferPropagation(RTLIL::Design* design)
	    : Propagation(design) {}

	void Run(Clocks& clocks) override {
	    clocks.Propagate(this);
	}
};

#endif  // PROPAGATION_H_
