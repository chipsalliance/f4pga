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
#include <cassert>
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

void Clocks::AddClockWire(const std::string& name, ClockWire& clock_wire) {
    AddClockWire(name, clock_wire.Wire(), clock_wire.Period(), clock_wire.RisingEdge(), clock_wire.FallingEdge());
}

std::vector<std::string> Clocks::GetClockNames() {
    std::vector<std::string> res;
    for (auto clock : clocks_) {
	res.push_back(clock.first);
#ifdef SDC_DEBUG
	log("Wires in clock %s:\n", clock.first.c_str());
	for (auto clock_wire : clock.second.GetClockWires()) {
	    log("create_clock -period %f -name %s -waveform {%f %f} %s\n",
	        clock_wire.Period(), clock.first.c_str(),
	        clock_wire.RisingEdge(), clock_wire.FallingEdge(),
	        clock_wire.WireName().c_str());
	}
#endif
    }
    return res;
}

void Clocks::Propagate(NaturalPropagation* pass) {
#ifdef SDC_DEBUG
    log("Start natural clock propagation\n");
#endif
    for (auto clock : clocks_) {
#ifdef SDC_DEBUG
	log("Processing clock %s\n", clock.first.c_str());
#endif
	auto clock_wires = clock.second.GetClockWires();
	for (auto clock_wire : clock_wires) {
	    auto aliases = pass->FindAliasWires(clock_wire.Wire());
	    AddClockWires(clock.first, aliases, clock_wire.Period(),
	                  clock_wire.RisingEdge(), clock_wire.FallingEdge());
	}
    }
#ifdef SDC_DEBUG
    log("Finish natural clock propagation\n\n");
#endif
}

void Clocks::Propagate(BufferPropagation* pass) {
#ifdef SDC_DEBUG
    log("Start buffer clock propagation\n");
#endif
    for (auto& clock : clocks_) {
#ifdef SDC_DEBUG
	log("Processing clock %s\n", clock.first.c_str());
#endif
	PropagateThroughBuffer(pass, clock, IBuf());
	PropagateThroughBuffer(pass, clock, Bufg());
    }
#ifdef SDC_DEBUG
    log("Finish buffer clock propagation\n\n");
#endif
}

void Clocks::Propagate(ClockDividerPropagation* pass) {
#ifdef SDC_DEBUG
    log("Start clock divider clock propagation\n");
#endif
    for (auto& clock : clocks_) {
#ifdef SDC_DEBUG
	log("Processing clock %s\n", clock.first.c_str());
#endif
	auto clock_wires = clock.second.GetClockWires();
	for (auto clock_wire : clock_wires) {
	    auto pll_clock_wires = pass->FindSinkClockWiresForCellType(
		    clock_wire, "PLLE2_ADV");
	    for (auto pll_clock_wire : pll_clock_wires) {
#ifdef SDC_DEBUG
		log("PLL wire: %s\n", pll_clock_wire.WireName().c_str());
#endif
		AddClockWire(pll_clock_wire.WireName(), pll_clock_wire);
	    }
	}
    }
#ifdef SDC_DEBUG
    log("Finish clock divider clock propagation\n\n");
#endif
}

void Clocks::PropagateThroughBuffer(BufferPropagation* pass,
                                    decltype(clocks_)::value_type clock,
                                    Buffer buffer) {
    auto clock_wires = clock.second.GetClockWires();
    for (auto clock_wire : clock_wires) {
	auto buf_wires = pass->FindSinkWiresForCellType(
	    clock_wire.Wire(), buffer.name, buffer.output);
	int path_delay(0);
	for (auto wire : buf_wires) {
#ifdef SDC_DEBUG
	    log("%s wire: %s\n", buffer.name.c_str(), wire->name.c_str());
#endif
	    path_delay += buffer.delay;
	    AddClockWire(wire->name.str(), wire, clock_wire.Period(),
	                 clock_wire.RisingEdge() + path_delay,
	                 clock_wire.FallingEdge() + path_delay);
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
    auto clock_wire = std::find_if(
        clock_wires_.begin(), clock_wires_.end(),
        [wire](ClockWire& clock_wire) { return clock_wire.Wire() == wire; });
    if (clock_wire == clock_wires_.end()) {
	clock_wires_.emplace_back(wire, period, rising_edge, falling_edge);
    } else {
	clock_wire->UpdatePeriod(period);
	clock_wire->UpdateWaveform(rising_edge, falling_edge);
    }
}

void ClockWire::UpdatePeriod(float period) {
    period_ = period;
    rising_edge_ = 0;
    falling_edge_ = period / 2;
}

void ClockWire::UpdateWaveform(float rising_edge, float falling_edge) {
    rising_edge_ = rising_edge;
    falling_edge_ = falling_edge;
    assert(falling_edge - rising_edge == period_ / 2);
}
