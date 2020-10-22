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

#include <vector>
#include "buffers.h"
#include "kernel/rtlil.h"

USING_YOSYS_NAMESPACE

class NaturalPropagation;
class BufferPropagation;
class ClockDividerPropagation;
class Propagation;

class Clock {
   public:
    Clock(const std::string& name, RTLIL::Wire* wire, float period,
          float rising_edge, float falling_edge);
    Clock(const std::string& name, std::vector<RTLIL::Wire*> wires,
          float period, float rising_edge, float falling_edge);
    Clock(RTLIL::Wire* wire, float period,
	    float rising_edge, float falling_edge);
    std::vector<RTLIL::Wire*> GetClockWires() { return clock_wires_; }
    const std::string& Name() const { return name_; }
    float Period() { return period_; }
    static float Period(RTLIL::Wire* clock_wire);
    float RisingEdge() { return rising_edge_; }
    static float RisingEdge(RTLIL::Wire* clock_wire);
    float FallingEdge() { return falling_edge_; }
    static float FallingEdge(RTLIL::Wire* clock_wire);
    RTLIL::Wire* ClockWire() { return clock_wire_; }
    void UpdateClock(RTLIL::Wire* wire, float period, float rising_edge,
                     float falling_edge);
    static std::string ClockWireName(RTLIL::Wire* wire);

   private:
    std::string name_;
    std::vector<RTLIL::Wire*> clock_wires_;
    RTLIL::Wire* clock_wire_;
    float period_;
    float rising_edge_;
    float falling_edge_;

    static std::pair<float, float> Waveform(RTLIL::Wire* clock_wire);
    void UpdateWires(RTLIL::Wire* wire);
    void UpdatePeriod(float period);
    void UpdateWaveform(float rising_edge, float falling_edge);
};

class Clocks {
   public:
    void AddClock(const std::string& name, std::vector<RTLIL::Wire*> wires,
                  float period, float rising_edge, float falling_edge);
    void AddClock(const std::string& name, RTLIL::Wire* wire, float period,
                  float rising_edge, float falling_edge);
    void AddClock(Clock& clock);
    void Propagate(RTLIL::Design* design, NaturalPropagation* pass);
    void Propagate(RTLIL::Design* design, BufferPropagation* pass);
    void Propagate(RTLIL::Design* design, ClockDividerPropagation* pass);
    static const std::vector<RTLIL::Wire*> GetClocks(RTLIL::Design* design);

   private:
    void PropagateThroughBuffer(Propagation* pass, RTLIL::Design* design, Clock& clock,
                                Buffer buffer);
};

#endif  // _CLOCKS_H_
