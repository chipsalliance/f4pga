/*
 * Copyright 2020-2022 F4PGA Authors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * SPDX-License-Identifier: Apache-2.0
 */
#include "propagation.h"
#include <cassert>

USING_YOSYS_NAMESPACE

void Propagation::PropagateThroughBuffers(Buffer buffer)
{
    for (auto &clock : Clocks::GetClocks(design_)) {
        auto &clock_wire = clock.second;
#ifdef SDC_DEBUG
        log("Clock wire %s\n", Clock::WireName(clock_wire).c_str());
#endif
        auto buf_wires = FindSinkWiresForCellType(clock_wire, buffer.type, buffer.output);
        int path_delay(0);
        for (auto wire : buf_wires) {
#ifdef SDC_DEBUG
            log("%s wire: %s\n", buffer.type.c_str(), RTLIL::id2cstr(wire->name));
#endif
            path_delay += buffer.delay;
            Clock::Add(wire, Clock::Period(clock_wire), Clock::RisingEdge(clock_wire) + path_delay, Clock::FallingEdge(clock_wire) + path_delay,
                       Clock::PROPAGATED);
        }
    }
}

std::vector<RTLIL::Wire *> Propagation::FindSinkWiresForCellType(RTLIL::Wire *driver_wire, const std::string &cell_type, const std::string &cell_port)
{
    std::vector<RTLIL::Wire *> wires;
    if (!driver_wire) {
        return wires;
    }
    auto cell = FindSinkCellOfType(driver_wire, cell_type);
    RTLIL::Wire *wire = FindSinkWireOnPort(cell, cell_port);
    if (wire) {
        wires.push_back(wire);
        auto further_wires = FindSinkWiresForCellType(wire, cell_type, cell_port);
        std::copy(further_wires.begin(), further_wires.end(), std::back_inserter(wires));
    }
    return wires;
}

RTLIL::Cell *Propagation::FindSinkCellOfType(RTLIL::Wire *wire, const std::string &type)
{
    RTLIL::Cell *sink_cell = NULL;
    if (!wire) {
        return sink_cell;
    }
    RTLIL::Module *top_module = design_->top_module();
    assert(top_module);
    std::string base_selection = top_module->name.str() + "/w:" + wire->name.str();
    pass_->extra_args(std::vector<std::string>{base_selection, "%co:+" + type, base_selection, "%d"}, 0, design_);
    auto selected_cells = top_module->selected_cells();
    // FIXME Handle more than one sink
    assert(selected_cells.size() <= 1);
    if (selected_cells.size() > 0) {
        sink_cell = selected_cells.at(0);
#ifdef SDC_DEBUG
        log("Found sink cell: %s\n", RTLIL::unescape_id(sink_cell->name).c_str());
#endif
    }
    return sink_cell;
}

RTLIL::Cell *Propagation::FindSinkCellOnPort(RTLIL::Wire *wire, const std::string &port)
{
    RTLIL::Cell *sink_cell = NULL;
    if (!wire) {
        return sink_cell;
    }
    RTLIL::Module *top_module = design_->top_module();
    assert(top_module);
    std::string base_selection = top_module->name.str() + "/w:" + wire->name.str();
    pass_->extra_args(std::vector<std::string>{base_selection, "%co:+[" + port + "]", base_selection, "%d"}, 0, design_);
    auto selected_cells = top_module->selected_cells();
    // FIXME Handle more than one sink
    assert(selected_cells.size() <= 1);
    if (selected_cells.size() > 0) {
        sink_cell = selected_cells.at(0);
#ifdef SDC_DEBUG
        log("Found sink cell: %s\n", RTLIL::unescape_id(sink_cell->name).c_str());
#endif
    }
    return sink_cell;
}

bool Propagation::WireHasSinkCell(RTLIL::Wire *wire)
{
    if (!wire) {
        return false;
    }
    RTLIL::Module *top_module = design_->top_module();
    assert(top_module);
    std::string base_selection = top_module->name.str() + "/w:" + wire->name.str();
    pass_->extra_args(std::vector<std::string>{base_selection, "%co:*", base_selection, "%d"}, 0, design_);
    auto selected_cells = top_module->selected_cells();
    return selected_cells.size() > 0;
}

RTLIL::Wire *Propagation::FindSinkWireOnPort(RTLIL::Cell *cell, const std::string &port_name)
{
    RTLIL::Wire *sink_wire = NULL;
    if (!cell) {
        return sink_wire;
    }
    RTLIL::Module *top_module = design_->top_module();
    assert(top_module);
    std::string base_selection = top_module->name.str() + "/c:" + cell->name.str();
    pass_->extra_args(std::vector<std::string>{base_selection, "%co:+[" + port_name + "]", base_selection, "%d"}, 0, design_);
    auto selected_wires = top_module->selected_wires();
    // FIXME Handle more than one sink
    assert(selected_wires.size() <= 1);
    if (selected_wires.size() > 0) {
        sink_wire = selected_wires.at(0);
#ifdef SDC_DEBUG
        log("Found sink wire: %s\n", RTLIL::unescape_id(sink_wire->name).c_str());
#endif
    }
    return sink_wire;
}

void NaturalPropagation::Run()
{
#ifdef SDC_DEBUG
    log("Start natural clock propagation\n");
#endif
    for (auto &clock : Clocks::GetClocks(design_)) {
        auto &clock_wire = clock.second;
#ifdef SDC_DEBUG
        log("Processing clock %s\n", RTLIL::id2cstr(clock_wire->name));
#endif
        auto aliases = FindAliasWires(clock_wire);
        Clock::Add(Clock::WireName(clock_wire), aliases, Clock::Period(clock_wire), Clock::RisingEdge(clock_wire), Clock::FallingEdge(clock_wire),
                   Clock::PROPAGATED);
    }
#ifdef SDC_DEBUG
    log("Finish natural clock propagation\n\n");
#endif
}

std::vector<RTLIL::Wire *> NaturalPropagation::FindAliasWires(RTLIL::Wire *wire)
{
    RTLIL::Module *top_module = design_->top_module();
    assert(top_module);
    std::vector<RTLIL::Wire *> alias_wires;
    pass_->extra_args(std::vector<std::string>{top_module->name.str() + "/w:" + wire->name.str(), "%a"}, 0, design_);
    for (auto module : design_->selected_modules()) {
        for (auto wire : module->selected_wires()) {
            alias_wires.push_back(wire);
        }
    }
    return alias_wires;
}

void BufferPropagation::Run()
{
#ifdef SDC_DEBUG
    log("Start buffer clock propagation\n");
    log("IBUF pass\n");
#endif
    PropagateThroughBuffers(IBuf());
#ifdef SDC_DEBUG
    log("BUFG pass\n");
#endif
    PropagateThroughBuffers(Bufg());
#ifdef SDC_DEBUG
    log("Finish buffer clock propagation\n\n");
#endif
}

void ClockDividerPropagation::Run()
{
#ifdef SDC_DEBUG
    log("Start clock divider clock propagation\n");
#endif
    PropagateThroughClockDividers(Pll());
    PropagateThroughBuffers(Bufg());
#ifdef SDC_DEBUG
    log("Finish clock divider clock propagation\n\n");
#endif
}

void ClockDividerPropagation::PropagateThroughClockDividers(ClockDivider divider)
{
    for (auto &clock : Clocks::GetClocks(design_)) {
        auto &clock_wire = clock.second;
#ifdef SDC_DEBUG
        log("Processing clock %s\n", Clock::WireName(clock_wire).c_str());
#endif
        PropagateClocksForCellType(clock_wire, divider.type);
    }
}

void ClockDividerPropagation::PropagateClocksForCellType(RTLIL::Wire *driver_wire, const std::string &cell_type)
{
    if (cell_type == "PLLE2_ADV") {
        RTLIL::Cell *cell = NULL;
        for (auto input : Pll::inputs) {
            cell = FindSinkCellOnPort(driver_wire, input);
            if (cell and RTLIL::unescape_id(cell->type) == cell_type) {
                break;
            }
        }
        if (!cell) {
            return;
        }
        Pll pll(cell, Clock::Period(driver_wire), Clock::RisingEdge(driver_wire));
        for (auto output : Pll::outputs) {
            RTLIL::Wire *wire = FindSinkWireOnPort(cell, output);
            // Don't add clocks on dangling wires
            // TODO Remove the workaround with the WireHasSinkCell check once the following issue is fixed:
            // https://github.com/SymbiFlow/yosys-f4pga-plugins/issues/59
            if (wire && WireHasSinkCell(wire)) {
                float clkout_period(pll.clkout_period.at(output));
                float clkout_rising_edge(pll.clkout_rising_edge.at(output));
                float clkout_falling_edge(pll.clkout_falling_edge.at(output));
                Clock::Add(wire, clkout_period, clkout_rising_edge, clkout_falling_edge, Clock::GENERATED);
            }
        }
    }
}
