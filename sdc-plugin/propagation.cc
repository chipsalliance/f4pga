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
#include "propagation.h"
#include <cassert>

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

std::vector<Clock> ClockDividerPropagation::FindSinkClocksForCellType(
    Clock driving_clock, const std::string& cell_type) {
    std::vector<Clock> clocks;
    auto clock_wire = driving_clock.ClockWire();
    if (cell_type == "PLLE2_ADV") {
	RTLIL::Cell* cell = NULL;
	for (auto input : Pll::inputs) {
	    cell = FindSinkCellOnPort(clock_wire, input);
	    if (cell and RTLIL::unescape_id(cell->type) == cell_type) {
		break;
	    }
	}
	if (!cell) {
	    return clocks;
	}
	Pll pll(cell, driving_clock.Period(), driving_clock.RisingEdge());
	for (auto output : Pll::outputs) {
	    RTLIL::Wire* wire = FindSinkWireOnPort(cell, output);
	    if (wire) {
		float clkout_period(pll.clkout_period.at(output));
		float clkout_rising_edge(pll.clkout_rising_edge.at(output));
		float clkout_falling_edge(pll.clkout_falling_edge.at(output));
		Clock clock(wire, clkout_period, clkout_rising_edge, clkout_falling_edge);
		clocks.push_back(clock);
	    }
	}
    }
    return clocks;
}

RTLIL::Cell* Propagation::FindSinkCellOfType(RTLIL::Wire* wire,
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
#ifdef SDC_DEBUG
	log("Found sink cell: %s\n",
	    RTLIL::unescape_id(sink_cell->name).c_str());
#endif
    }
    return sink_cell;
}

std::vector<RTLIL::Wire*> Propagation::FindSinkWiresForCellType(
    RTLIL::Wire* driver_wire, const std::string& cell_type,
    const std::string& cell_port) {
    std::vector<RTLIL::Wire*> wires;
    if (!driver_wire) {
	return wires;
    }
    auto cell = FindSinkCellOfType(driver_wire, cell_type);
    RTLIL::Wire* wire = FindSinkWireOnPort(cell, cell_port);
    if (wire) {
	wires.push_back(wire);
	auto further_wires =
	    FindSinkWiresForCellType(wire, cell_type, cell_port);
	std::copy(further_wires.begin(), further_wires.end(),
	          std::back_inserter(wires));
    }
    return wires;
}

RTLIL::Cell* Propagation::FindSinkCellOnPort(RTLIL::Wire* wire,
                                             const std::string& port) {
    RTLIL::Cell* sink_cell = NULL;
    if (!wire) {
	return sink_cell;
    }
    RTLIL::Module* top_module = design_->top_module();
    assert(top_module);
    std::string base_selection =
        top_module->name.str() + "/w:" + wire->name.str();
    pass_->extra_args(
        std::vector<std::string>{base_selection, "%co:+[" + port + "]",
                                 base_selection, "%d"},
        0, design_);
    auto selected_cells = top_module->selected_cells();
    // FIXME Handle more than one sink
    assert(selected_cells.size() <= 1);
    if (selected_cells.size() > 0) {
	sink_cell = selected_cells.at(0);
#ifdef SDC_DEBUG
	log("Found sink cell: %s\n",
	    RTLIL::unescape_id(sink_cell->name).c_str());
#endif
    }
    return sink_cell;
}

RTLIL::Wire* Propagation::FindSinkWireOnPort(RTLIL::Cell* cell,
                                             const std::string& port_name) {
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
#ifdef SDC_DEBUG
	log("Found sink wire: %s\n",
	    RTLIL::unescape_id(sink_wire->name).c_str());
#endif
    }
    return sink_wire;
}
