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
#ifndef _CLOCKS_H_
#define _CLOCKS_H_

#include <unordered_map>
#include <vector>
#include "kernel/rtlil.h"

USING_YOSYS_NAMESPACE

class NaturalPropagation;
class BufferPropagation;

class ClockWire {
   public:
    ClockWire(RTLIL::Wire* wire, float period, float rising_edge,
              float falling_edge)
        : wire_(wire),
          period_(period),
          rising_edge_(rising_edge),
          falling_edge_(falling_edge) {}
    RTLIL::Wire* Wire() { return wire_; }
    float Period() { return period_; }
    float RisingEdge() { return rising_edge_; }
    float FallingEdge() { return falling_edge_; }

   private:
    RTLIL::Wire* wire_;
    float period_;
    float rising_edge_;
    float falling_edge_;
};

class Clock {
   public:
    Clock(const std::string& name) : name_(name) {}
    Clock(const std::string& name, RTLIL::Wire* wire, float period,
          float rising_edge, float falling_edge);
    void AddClockWire(RTLIL::Wire* wire, float period, float rising_edge,
                      float falling_edge);
    std::vector<ClockWire> GetClockWires() { return clock_wires_; }
    ClockWire* RootWire() {
	if (clock_wires_.size()) {
	    return &clock_wires_[0];
	} else {
	    return NULL;
	}
    }

   private:
    std::string name_;
    std::vector<ClockWire> clock_wires_;
};

class Clocks {
   public:
    void AddClockWires(const std::string& name,
                       const std::vector<RTLIL::Wire*>& wires, float period,
                       float rising_edge, float falling_edge);
    void AddClockWire(const std::string& name, RTLIL::Wire* wire, float period);
    void AddClockWire(const std::string& name, RTLIL::Wire* wire, float period,
                      float rising_edge, float falling_edge);
    std::vector<std::string> GetClockNames();
    std::vector<std::string> GetClockWireNames(const std::string& clock_name);
    void Propagate(NaturalPropagation* pass);
    void Propagate(BufferPropagation* pass);

   private:
    std::unordered_map<std::string, Clock> clocks_;
};

#endif  // _CLOCKS_H_
