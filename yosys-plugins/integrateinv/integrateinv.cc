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
 *
 */

#include "kernel/register.h"
#include "kernel/rtlil.h"
#include "kernel/sigtools.h"

USING_YOSYS_NAMESPACE
PRIVATE_NAMESPACE_BEGIN

/// A structure representing a pin
struct Pin {
    RTLIL::Cell *cell;    /// Cell pointer
    RTLIL::IdString port; /// Cell port name
    int bit;              /// Port bit index

    Pin(RTLIL::Cell *_cell, const RTLIL::IdString &_port, int _bit = 0) : cell(_cell), port(_port), bit(_bit) {}

    Pin(const Pin &ref) = default;

    unsigned int hash() const
    {
        if (cell == nullptr) {
            return mkhash_add(port.hash(), bit);
        } else {
            return mkhash_add(mkhash(cell->hash(), port.hash()), bit);
        }
    };
};

bool operator==(const Pin &lhs, const Pin &rhs) { return (lhs.cell == rhs.cell) && (lhs.port == rhs.port) && (lhs.bit == rhs.bit); }

struct IntegrateInv : public Pass {

    /// Temporary SigBit to SigBit helper map.
    SigMap m_SigMap;
    /// Map of SigBit objects to inverter cells.
    dict<RTLIL::SigBit, RTLIL::Cell *> m_InvMap;
    /// Map of inverter cells that can potentially be integrated and invertable
    /// pins that they are connected to
    dict<RTLIL::Cell *, pool<Pin>> m_Inverters;
    /// Map of invertable pins and names of parameters controlling inversions
    dict<Pin, RTLIL::IdString> m_InvParams;

    IntegrateInv()
        : Pass("integrateinv", "Integrates inverters ($_NOT_ cells) into ports "
                               "with 'invertible_pin' attribute set")
    {
    }

    void help() override
    {
        log("\n");
        log("    integrateinv [selection]");
        log("\n");
        log("This pass integrates inverters into cells that have ports with the\n");
        log("'invertible_pin' attribute set. The attribute should contain the name\n");
        log("of a parameter controlling the inversion.\n");
        log("\n");
        log("This pass is essentially the opposite of the 'extractinv' pass.\n");
        log("\n");
    }

    void execute(std::vector<std::string> a_Args, RTLIL::Design *a_Design) override
    {
        log_header(a_Design, "Executing INTEGRATEINV pass (integrating pin inverters).\n");

        extra_args(a_Args, 1, a_Design);

        // Process modules
        for (auto module : a_Design->selected_modules()) {

            // Setup the SigMap
            m_SigMap.clear();
            m_SigMap.set(module);

            m_Inverters.clear();
            m_InvParams.clear();

            // Setup inverter map
            buildInverterMap(module);

            // Identify inverters that can be integrated and assign them with
            // lists of cells and ports to integrate with
            for (auto cell : module->selected_cells()) {
                collectInverters(cell);
            }

            // Integrate inverters
            integrateInverters();
        }

        // Clear maps
        m_SigMap.clear();

        m_InvMap.clear();
        m_Inverters.clear();
        m_InvParams.clear();
    }

    void buildInverterMap(RTLIL::Module *a_Module)
    {
        m_InvMap.clear();

        for (auto cell : a_Module->cells()) {

            // Skip non-inverters
            if (cell->type != RTLIL::escape_id("$_NOT_")) {
                continue;
            }

            // Get output connection
            auto sigspec = cell->getPort(RTLIL::escape_id("Y"));
            auto sigbit = m_SigMap(sigspec.bits().at(0));

            // Store
            log_assert(m_InvMap.count(sigbit) == 0);
            m_InvMap[sigbit] = cell;
        }
    }

    void collectInverters(RTLIL::Cell *a_Cell)
    {
        auto module = a_Cell->module;
        auto design = module->design;

        for (auto conn : a_Cell->connections()) {
            auto port = conn.first;
            auto sigspec = conn.second;

            // Consider only inputs.
            if (!a_Cell->input(port)) {
                continue;
            }

            // Get the cell module
            auto cellModule = design->module(a_Cell->type);
            if (!cellModule) {
                continue;
            }

            // Get wire.
            auto wire = cellModule->wire(port);
            if (!wire) {
                continue;
            }

            // Check if the pin has an embedded inverter.
            auto it = wire->attributes.find(ID::invertible_pin);
            if (it == wire->attributes.end()) {
                continue;
            }

            // Decode the parameter name.
            RTLIL::IdString paramName = RTLIL::escape_id(it->second.decode_string());

            // Look for connected inverters
            auto sigbits = sigspec.bits();
            for (size_t bit = 0; bit < sigbits.size(); ++bit) {

                auto sigbit = sigbits[bit];
                if (!sigbit.wire) {
                    continue;
                }

                sigbit = m_SigMap(sigbit);

                // Get the inverter if any
                if (!m_InvMap.count(sigbit)) {
                    continue;
                }
                auto inv = m_InvMap.at(sigbit);

                // Save the inverter pin and the parameter name
                auto pin = Pin(a_Cell, port, bit);

                auto &list = m_Inverters[inv];
                list.insert(pin);

                log_assert(m_InvParams.count(pin) == 0);
                m_InvParams[pin] = paramName;
            }
        }
    }

    void integrateInverters()
    {

        for (auto it : m_Inverters) {
            auto inv = it.first;
            auto pins = it.second;

            // List all sinks of the inverter
            auto sinks = getSinksForDriver(Pin(inv, RTLIL::escape_id("Y")));

            // If the inverter drives only invertable pins then integrate it
            if (sinks == pins) {
                log("Integrating inverter %s into:\n", log_id(inv->name));

                // Integrate into each pin
                for (auto pin : pins) {
                    log_assert(pin.cell != nullptr);
                    log(" %s.%s[%d]\n", log_id(pin.cell->name), log_id(pin.port), pin.bit);

                    // Change the connection
                    auto sigspec = pin.cell->getPort(pin.port);
                    auto sigbits = sigspec.bits();

                    log_assert((size_t)pin.bit < sigbits.size());
                    sigbits[pin.bit] = RTLIL::SigBit(inv->getPort(RTLIL::escape_id("A"))[0]);
                    pin.cell->setPort(pin.port, RTLIL::SigSpec(sigbits));

                    // Get the control parameter
                    log_assert(m_InvParams.count(pin) != 0);
                    auto paramName = m_InvParams[pin];

                    RTLIL::Const invMask;
                    auto param = pin.cell->parameters.find(paramName);
                    if (param == pin.cell->parameters.end()) {
                        invMask = RTLIL::Const(0, sigspec.size());
                    } else {
                        invMask = RTLIL::Const(param->second);
                    }

                    // Check width.
                    if (invMask.size() != sigspec.size()) {
                        log_error("The inversion parameter needs to be the same width as "
                                  "the port (%s port %s parameter %s)",
                                  log_id(pin.cell->name), log_id(pin.port), log_id(paramName));
                    }

                    // Toggle bit in the control parameter bitmask
                    if (invMask[pin.bit] == RTLIL::State::S0) {
                        invMask[pin.bit] = RTLIL::State::S1;
                    } else if (invMask[pin.bit] == RTLIL::State::S1) {
                        invMask[pin.bit] = RTLIL::State::S0;
                    } else {
                        log_error("The inversion parameter must contain only 0s and 1s (%s "
                                  "parameter %s)\n",
                                  log_id(pin.cell->name), log_id(paramName));
                    }

                    // Set the parameter back
                    pin.cell->setParam(paramName, invMask);
                }

                // Remove the inverter
                inv->module->remove(inv);
            }
        }
    }

    pool<Pin> getSinksForDriver(const Pin &a_Driver)
    {
        auto module = a_Driver.cell->module;
        pool<Pin> sinks;

        // The driver has to be an output pin
        if (!a_Driver.cell->output(a_Driver.port)) {
            return sinks;
        }

        // Get the driver sigbit
        auto driverSigspec = a_Driver.cell->getPort(a_Driver.port);
        auto driverSigbit = m_SigMap(driverSigspec.bits().at(a_Driver.bit));

        // Look for connected sinks
        for (auto cell : module->cells()) {
            for (auto conn : cell->connections()) {
                auto port = conn.first;
                auto sigspec = conn.second;

                // Consider only sinks (inputs)
                if (!cell->input(port)) {
                    continue;
                }

                // Check all sigbits
                auto sigbits = sigspec.bits();
                for (size_t bit = 0; bit < sigbits.size(); ++bit) {

                    auto sigbit = sigbits[bit];
                    if (!sigbit.wire) {
                        continue;
                    }

                    // Got a sink pin of another cell
                    sigbit = m_SigMap(sigbit);
                    if (sigbit == driverSigbit) {
                        sinks.insert(Pin(cell, port, bit));
                    }
                }
            }
        }

        // Look for connected top-level output ports
        for (auto conn : module->connections()) {
            auto dst = conn.first;
            auto src = conn.second;

            auto sigbits = dst.bits();
            for (size_t bit = 0; bit < sigbits.size(); ++bit) {

                auto sigbit = sigbits[bit];
                if (!sigbit.wire) {
                    continue;
                }

                if (!sigbit.wire->port_output) {
                    continue;
                }

                sigbit = m_SigMap(sigbit);
                if (sigbit == driverSigbit) {
                    sinks.insert(Pin(nullptr, sigbit.wire->name, bit));
                }
            }
        }

        return sinks;
    }

} IntegrateInv;

PRIVATE_NAMESPACE_END
