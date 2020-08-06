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
#include <cassert>
#include "propagation.h"

USING_YOSYS_NAMESPACE

std::vector<RTLIL::Wire*> NaturalPropagation::FindAliasWires(
    RTLIL::Wire* wire) {
    RTLIL::Module* top_module = design_->top_module();
    assert(top_module);
    std::vector<RTLIL::Wire*> alias_wires;
    pass_->extra_args(
        std::vector<std::string>{
            top_module->name.str() + "/w:" + wire->name.str(), "%a"},
        0, design_);
    for (auto module : design_->selected_modules()) {
	for (auto wire : module->selected_wires()) {
	    alias_wires.push_back(wire);
	}
    }
    return alias_wires;
}

std::vector<ClockWire> ClockDividerPropagation::FindSinkWiresForCellType(ClockWire& driver_wire,
                                             const std::string& cell_type) {
    std::vector<ClockWire> wires;
    auto cell = FindSinkCell(driver_wire.Wire(), cell_type);
    if (!cell) {
	return wires;
    }
    if (cell_type == "PLLE2_ADV") {
    //CLKOUT[0-5]_PERIOD = CLKIN1_PERIOD * CLKOUT[0-5]_DIVIDE / CLKFBOUT_MULT
	Pll pll(cell);
	log("c1: %f, c2: %f", pll.clkin1_period, pll.clkin2_period);
	/* for (auto output : pll.outputs) { */
	/*     RTLIL::Wire* wire = FindSinkWireOnPort(pll.cell, output); */
	/*     if (wire) { */
	/*     wires.push_back(wire); */
	/*     auto further_wires = FindSinkWiresForCellType(wire, cell_type, cell_port); */
	/*     std::copy(further_wires.begin(), further_wires.end(), */
	/* 	    std::back_inserter(wires)); */
	/* } */
    }
    return wires;
}

std::vector<RTLIL::Wire*> Propagation::FindSinkWiresForCellType(RTLIL::Wire* driver_wire,
                                             const std::string& cell_type, const std::string& cell_port) {
    std::vector<RTLIL::Wire*> wires;
    if (!driver_wire) {
	return wires;
    }
    auto cell = FindSinkCell(driver_wire, cell_type);
    RTLIL::Wire* wire = FindSinkWireOnPort(cell, cell_port);
    if (wire) {
	wires.push_back(wire);
	auto further_wires = FindSinkWiresForCellType(wire, cell_type, cell_port);
	std::copy(further_wires.begin(), further_wires.end(),
	          std::back_inserter(wires));
    }
    return wires;
}

std::vector<RTLIL::Wire*> BufferPropagation::FindSinkWiresForCellType2(RTLIL::Wire* driver_wire,
                                             const std::string& type) {
    if (!driver_wire) {
	return std::vector<RTLIL::Wire*>();
    }
    RTLIL::Module* top_module = design_->top_module();
    assert(top_module);
    std::string base_selection =
        top_module->name.str() + "/w:" + driver_wire->name.str();
    pass_->extra_args(std::vector<std::string>{base_selection, "%co*:+" + type,
                                               base_selection, "%d"},
                      0, design_);
    return top_module->selected_wires();
}

RTLIL::Cell* Propagation::FindSinkCell(RTLIL::Wire* wire,
                                             const std::string& type) {
    RTLIL::Cell* sink_cell = NULL;
    if (!wire) {
	return sink_cell;
    }
    RTLIL::Module* top_module = design_->top_module();
    assert(top_module);
    std::string base_selection =
        top_module->name.str() + "/w:" + wire->name.str();
    pass_->extra_args(std::vector<std::string>{base_selection, "%co:+" + type,
                                               base_selection, "%d"},
                      0, design_);
    auto selected_cells = top_module->selected_cells();
    // FIXME Handle more than one sink
    assert(selected_cells.size() <= 1);
    if (selected_cells.size() > 0) {
	sink_cell = selected_cells.at(0);
	log("Found sink cell: %s\n", sink_cell->name.c_str());
    }
    return sink_cell;
}

RTLIL::Wire* Propagation::FindSinkWireOnPort(
    RTLIL::Cell* cell, const std::string& port_name) {
    RTLIL::Wire* sink_wire = NULL;
    if (!cell) {
	return sink_wire;
    }
    RTLIL::Module* top_module = design_->top_module();
    assert(top_module);
    std::string base_selection =
        top_module->name.str() + "/c:" + cell->name.str();
    pass_->extra_args(
        std::vector<std::string>{base_selection, "%co:+[" + port_name + "]",
                                 base_selection, "%d"},
        0, design_);
    auto selected_wires = top_module->selected_wires();
    // FIXME Handle more than one sink
    assert(selected_wires.size() <= 1);
    if (selected_wires.size() > 0) {
	sink_wire = selected_wires.at(0);
	log("Found sink wire: %s\n", sink_wire->name.c_str());
    }
    return sink_wire;
}
