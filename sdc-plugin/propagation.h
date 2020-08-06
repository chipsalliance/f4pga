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

#include "clocks.h"

USING_YOSYS_NAMESPACE

class Propagation {
   public:
    Propagation(RTLIL::Design* design, Pass* pass)
        : design_(design), pass_(pass) {}

    virtual void Run(Clocks& clocks) = 0;
    std::vector<RTLIL::Wire*> FindSinkWiresForCellType(
        RTLIL::Wire* driver_wire, const std::string& cell_type,
        const std::string& cell_port);

   protected:
    RTLIL::Design* design_;
    Pass* pass_;

    RTLIL::Cell* FindSinkCellOfType(RTLIL::Wire* wire, const std::string& type);
    RTLIL::Cell* FindSinkCellOnPort(RTLIL::Wire* wire, const std::string& port);
    RTLIL::Wire* FindSinkWireOnPort(RTLIL::Cell* cell,
                                    const std::string& port_name);
};

class NaturalPropagation : public Propagation {
   public:
    NaturalPropagation(RTLIL::Design* design, Pass* pass)
        : Propagation(design, pass) {}

    void Run(Clocks& clocks) override { clocks.Propagate(this); }
    std::vector<RTLIL::Wire*> FindAliasWires(RTLIL::Wire* wire);
};

class BufferPropagation : public Propagation {
   public:
    BufferPropagation(RTLIL::Design* design, Pass* pass)
        : Propagation(design, pass) {}

    void Run(Clocks& clocks) override { clocks.Propagate(this); }

   private:
    std::vector<RTLIL::Wire*> FindSinkWiresForCellType2(
        RTLIL::Wire* driver_wire, const std::string& type);
};

class ClockDividerPropagation : public Propagation {
   public:
    ClockDividerPropagation(RTLIL::Design* design, Pass* pass)
        : Propagation(design, pass) {}

    void Run(Clocks& clocks) override { clocks.Propagate(this); }
    std::vector<ClockWire> FindSinkWiresForCellType(
        ClockWire& driver_wire, const std::string& cell_type);
};
#endif  // PROPAGATION_H_
