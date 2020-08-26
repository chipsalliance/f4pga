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

void Clocks::AddClock(const std::string& name, std::vector<RTLIL::Wire*> wires,
                      float period, float rising_edge, float falling_edge) {
    AddClockWires(name, wires, period, rising_edge, falling_edge);
}

void Clocks::AddClock(const std::string& name, RTLIL::Wire* wire, float period,
                      float rising_edge, float falling_edge) {
    auto clock =
        std::find_if(clocks_.begin(), clocks_.end(),
                     [&](Clock& clock) { return clock.Name() == name; });
    if (clock != clocks_.end()) {
	log("Clock %s already exists and will be overwritten\n", name.c_str());
	clock->UpdateClock(wire, period, rising_edge, falling_edge);
    } else {
	log("Inserting clock %s with period %f, r:%f, f:%f\n", name.c_str(),
	    period, rising_edge, falling_edge);
	clocks_.emplace_back(name, wire, period, rising_edge, falling_edge);
    }
}

void Clocks::AddClock(Clock& clock) {
    AddClock(clock.Name(), clock.GetClockWires(), clock.Period(),
             clock.RisingEdge(), clock.FallingEdge());
}

void Clocks::AddClockWires(const std::string& name,
                           std::vector<RTLIL::Wire*> wires, float period,
                           float rising_edge, float falling_edge) {
    std::for_each(wires.begin(), wires.end(), [&, this](RTLIL::Wire* wire) {
	AddClockWire(name, wire, period, rising_edge, falling_edge);
    });
}

void Clocks::AddClockWire(const std::string& name, RTLIL::Wire* wire,
                          float period, float rising_edge, float falling_edge) {
    auto clock =
        std::find_if(clocks_.begin(), clocks_.end(),
                     [&](Clock& clock) { return clock.Name() == name; });
    if (clock == clocks_.end()) {
	AddClock(name, wire, period, rising_edge, falling_edge);
    } else {
	clock->AddWire(wire);
    }
}

std::vector<std::string> Clocks::GetClockNames() {
    std::vector<std::string> res;
    for (auto clock : clocks_) {
	res.push_back(clock.Name());
#ifdef SDC_DEBUG
	std::stringstream ss;
	for (auto clock_wire : clock.GetClockWires()) {
	    ss << RTLIL::unescape_id(clock_wire->name) << " ";
	}
	log("create_clock -period %f -name %s -waveform {%f %f} %s\n",
	    clock.Period(), clock.Name().c_str(), clock.RisingEdge(),
	    clock.FallingEdge(), ss.str().c_str());
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
	log("Processing clock %s\n", clock.Name().c_str());
#endif
	auto clock_wires = clock.GetClockWires();
	for (auto clock_wire : clock_wires) {
	    auto aliases = pass->FindAliasWires(clock_wire);
	    AddClockWires(clock.Name(), aliases, clock.Period(),
	                  clock.RisingEdge(), clock.FallingEdge());
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
    for (auto clock : clocks_) {
#ifdef SDC_DEBUG
	log("Processing clock %s\n", clock.Name().c_str());
#endif
	PropagateThroughBuffer(pass, clock, IBuf());
    }
    for (auto clock : clocks_) {
#ifdef SDC_DEBUG
	log("Processing clock %s\n", clock.Name().c_str());
#endif
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
    for (auto clock : clocks_) {
#ifdef SDC_DEBUG
	log("Processing clock %s\n", clock.Name().c_str());
#endif
	auto clock_wires = clock.GetClockWires();
	for (auto clock_wire : clock_wires) {
	    auto pll_clocks =
	        pass->FindSinkClocksForCellType(clock_wire, "PLLE2_ADV");
	    for (auto pll_clock : pll_clocks) {
#ifdef SDC_DEBUG
		log("PLL clock: %s\n", pll_clock.Name().c_str());
#endif
		AddClock(pll_clock);
		PropagateThroughBuffer(pass, pll_clock, Bufg());
	    }
	}
    }
#ifdef SDC_DEBUG
    log("Finish clock divider clock propagation\n\n");
#endif
}

void Clocks::PropagateThroughBuffer(Propagation* pass, Clock& clock,
                                    Buffer buffer) {
    auto clock_wires = clock.GetClockWires();
    for (auto clock_wire : clock_wires) {
#ifdef SDC_DEBUG
	log("Clock wire %s\n", RTLIL::unescape_id(clock_wire->name).c_str());
#endif
	auto buf_wires = pass->FindSinkWiresForCellType(clock_wire, buffer.name,
	                                                buffer.output);
	int path_delay(0);
	for (auto wire : buf_wires) {
#ifdef SDC_DEBUG
	    log("%s wire: %s\n", buffer.name.c_str(),
	        RTLIL::unescape_id(wire->name).c_str());
#endif
	    path_delay += buffer.delay;
	    AddClock(RTLIL::unescape_id(wire->name), wire, clock.Period(),
	             clock.RisingEdge() + path_delay,
	             clock.FallingEdge() + path_delay);
	}
    }
}

void Clocks::WriteSdc(std::ostream& file) {
    for (auto& clock : clocks_) {
	auto clock_wires = clock.GetClockWires();
	// FIXME: Input port nets are not found in VPR
	if (std::all_of(clock_wires.begin(), clock_wires.end(),
	                [&](RTLIL::Wire* wire) { return wire->port_input; })) {
	    continue;
	}
	file << "create_clock -period " << clock.Period();
	file << " -waveform {" << clock.RisingEdge() << " "
	     << clock.FallingEdge() << "}";
	for (auto clock_wire : clock_wires) {
	    if (clock_wire->port_input) {
		continue;
	    }
	    file << " " << Clock::ClockWireName(clock_wire);
	}
	file << std::endl;
    }
}

Clock::Clock(const std::string& name, RTLIL::Wire* wire, float period,
             float rising_edge, float falling_edge)
    : name_(name),
      period_(period),
      rising_edge_(rising_edge),
      falling_edge_(falling_edge) {
    AddWire(wire);
}

Clock::Clock(const std::string& name, std::vector<RTLIL::Wire*> wires,
             float period, float rising_edge, float falling_edge)
    : name_(name),
      period_(period),
      rising_edge_(rising_edge),
      falling_edge_(falling_edge) {
    std::for_each(wires.begin(), wires.end(),
                  [&, this](RTLIL::Wire* wire) { AddWire(wire); });
}

void Clock::AddWire(RTLIL::Wire* wire) {
    auto clock_wire = std::find(clock_wires_.begin(), clock_wires_.end(), wire);
    if (clock_wire == clock_wires_.end()) {
	clock_wires_.push_back(wire);
    }
}

void Clock::UpdateClock(RTLIL::Wire* wire, float period, float rising_edge,
                        float falling_edge) {
    UpdateWires(wire);
    UpdatePeriod(period);
    UpdateWaveform(rising_edge, falling_edge);
}

void Clock::UpdateWires(RTLIL::Wire* wire) {
    if (std::find(clock_wires_.begin(), clock_wires_.end(), wire) ==
        clock_wires_.end()) {
	clock_wires_.push_back(wire);
    }
}

void Clock::UpdatePeriod(float period) {
    period_ = period;
    rising_edge_ = 0;
    falling_edge_ = period / 2;
}

void Clock::UpdateWaveform(float rising_edge, float falling_edge) {
    rising_edge_ = rising_edge;
    falling_edge_ = falling_edge;
    assert(falling_edge - rising_edge == period_ / 2);
}

std::string Clock::ClockWireName(RTLIL::Wire* wire) {
    if (!wire) {
	return std::string();
    }
    std::string wire_name(RTLIL::unescape_id(wire->name));
    return std::regex_replace(wire_name, std::regex{"\\$"}, "\\$");
}
