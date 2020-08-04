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
#include "clocks.h"
#include <algorithm>
#include "kernel/log.h"
#include "kernel/register.h"
#include "propagation.h"

void Clocks::AddClockWires(const std::string& name,
                           const std::vector<RTLIL::Wire*>& wires, float period,
                           float rising_edge, float falling_edge) {
    std::for_each(wires.begin(), wires.end(), [&, this](RTLIL::Wire* wire) {
	AddClockWire(name, wire, period, rising_edge, falling_edge);
    });
}

void Clocks::AddClockWire(const std::string& name, RTLIL::Wire* wire,
                          float period) {
    // Set default duty cycle 50%
    AddClockWire(name, wire, period, 0, period / 2);
}

void Clocks::AddClockWire(const std::string& name, RTLIL::Wire* wire,
                          float period, float rising_edge, float falling_edge) {
    auto clock = clocks_.find(name);
    if (clock == clocks_.end()) {
	clock = clocks_.emplace(std::make_pair(name, Clock(name))).first;
    }
    clock->second.AddClockWire(wire, period, rising_edge, falling_edge);
}

std::vector<std::string> Clocks::GetClockNames() {
    std::vector<std::string> res;
    for (auto clock : clocks_) {
	res.push_back(clock.first);
	log("Wires in clock %s:\n", clock.first.c_str());
	for (auto wire_name : GetClockWireNames(clock.first)) {
	    log("%s\n", wire_name.c_str());
	}
    }
    return res;
}

std::vector<std::string> Clocks::GetClockWireNames(
    const std::string& clock_name) {
    std::vector<std::string> res;
    auto clock = clocks_.find(clock_name);
    if (clock != clocks_.end()) {
	for (auto clock_wire : clock->second.GetClockWires()) {
	    auto wire_name = clock_wire.Wire()->name.str();
	    res.push_back(wire_name);
	}
    }
    return res;
}

void Clocks::Propagate(NaturalPropagation* pass) {
    for (auto clock : clocks_) {
	log("Processing clock %s\n", clock.first.c_str());
	auto clock_wires = clock.second.GetClockWires();
	for (auto clock_wire : clock_wires) {
	    auto aliases = pass->FindAliasWires(clock_wire.Wire());
	    AddClockWires(clock.first, aliases, clock_wire.Period(),
	                  clock_wire.RisingEdge(), clock_wire.FallingEdge());
	}
    }
}

void Clocks::Propagate(BufferPropagation* pass) {
    for (auto clock : clocks_) {
	log("Processing clock %s\n", clock.first.c_str());
	auto clock_wires = clock.second.GetClockWires();
	for (auto clock_wire : clock_wires) {
	    log("Clock wire %s\n", clock_wire.Wire()->name.c_str());
	    auto ibuf_wires = pass->FindIBufWires(clock_wire.Wire());
	    for (auto wire : ibuf_wires) {
		log("IBUF wire: %s\n", wire->name.c_str());
	    }
	}

    }
}

Clock::Clock(const std::string& name, RTLIL::Wire* wire, float period,
             float rising_edge, float falling_edge)
    : Clock(name) {
    AddClockWire(wire, period, rising_edge, falling_edge);
}

void Clock::AddClockWire(RTLIL::Wire* wire, float period, float rising_edge,
                         float falling_edge) {
    if (std::find_if(clock_wires_.begin(), clock_wires_.end(),
                     [wire](ClockWire& clock_wire) {
	                 return clock_wire.Wire() == wire;
                     }) == clock_wires_.end()) {
	clock_wires_.emplace_back(wire, period, rising_edge, falling_edge);
    }
}
