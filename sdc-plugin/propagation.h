/*
 * Copyright (C) 2019-2022 The SymbiFlow Authors
 *
 * Use of this source code is governed by a ISC-style
 * license that can be found in the LICENSE file or at
 * https://opensource.org/licenses/ISC
 *
 * SPDX-License-Identifier: ISC
 */
#ifndef _PROPAGATION_H_
#define _PROPAGATION_H_

#include "clocks.h"

USING_YOSYS_NAMESPACE

class Propagation
{
  public:
    Propagation(RTLIL::Design *design, Pass *pass) : design_(design), pass_(pass) {}
    virtual ~Propagation() {}

    virtual void Run() = 0;

  protected:
    RTLIL::Design *design_;
    Pass *pass_;

    // This propagation doesn't change the clock so the sink wire is only marked
    // as propagated clock signal, but has the properties of the driving clock
    void PropagateThroughBuffers(Buffer buffer);
    std::vector<RTLIL::Wire *> FindSinkWiresForCellType(RTLIL::Wire *driver_wire, const std::string &cell_type, const std::string &cell_port);
    RTLIL::Cell *FindSinkCellOfType(RTLIL::Wire *wire, const std::string &type);
    RTLIL::Cell *FindSinkCellOnPort(RTLIL::Wire *wire, const std::string &port);
    RTLIL::Wire *FindSinkWireOnPort(RTLIL::Cell *cell, const std::string &port_name);
    bool WireHasSinkCell(RTLIL::Wire *wire);
};

class NaturalPropagation : public Propagation
{
  public:
    NaturalPropagation(RTLIL::Design *design, Pass *pass) : Propagation(design, pass) {}

    void Run() override;
    std::vector<RTLIL::Wire *> FindAliasWires(RTLIL::Wire *wire);
};

class BufferPropagation : public Propagation
{
  public:
    BufferPropagation(RTLIL::Design *design, Pass *pass) : Propagation(design, pass) {}

    void Run() override;
};

class ClockDividerPropagation : public Propagation
{
  public:
    ClockDividerPropagation(RTLIL::Design *design, Pass *pass) : Propagation(design, pass) {}

    void Run() override;
    void PropagateClocksForCellType(RTLIL::Wire *driver_wire, const std::string &cell_type);
    void PropagateThroughClockDividers(ClockDivider divider);
};
#endif // PROPAGATION_H_
