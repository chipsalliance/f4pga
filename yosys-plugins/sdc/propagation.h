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
