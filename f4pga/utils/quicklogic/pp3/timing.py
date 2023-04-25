#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# Copyright (C) 2022 F4PGA Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0
import statistics

from copy import deepcopy
from collections import defaultdict, namedtuple

from f4pga.utils.quicklogic.pp3.data_structs import VprSwitch, MuxEdgeTiming, DriverTiming, SinkTiming
from f4pga.utils.quicklogic.pp3.utils import yield_muxes, add_named_item

# =============================================================================


def linear_regression(xs, ys):
    """
    Computes linear regression coefficients
    https://en.wikipedia.org/wiki/Simple_linear_regression

    Returns a and b coefficients of the function f(y) = a * x + b
    """
    x_mean = statistics.mean(xs)
    y_mean = statistics.mean(ys)

    num, den = 0.0, 0.0
    for x, y in zip(xs, ys):
        num += (x - x_mean) * (y - y_mean)
        den += (x - x_mean) * (x - x_mean)

    a = num / den
    b = y_mean - a * x_mean

    return a, b


# =============================================================================


def create_vpr_switch(type, tdel, r, c):
    """
    Creates a VPR switch with the given parameters. Autmatically generates
    its name with these parameters encoded.

    The VPR switch parameters are:
    - type: Switch type. See VPR docs for the available types
    - tdel: Constant propagation delay [s]
    - r:    Internal resistance [ohm]
    - c:    Internal capacitance (active only when the switch is "on") [F]
    """

    # Format the switch name
    name = ["sw"]
    name += ["T{:>08.6f}".format(tdel * 1e9)]
    name += ["R{:>08.6f}".format(r)]
    name += ["C{:>010.6f}".format(c * 1e12)]

    # Create the VPR switch
    switch = VprSwitch(
        name="_".join(name),
        type=type,
        t_del=tdel,
        r=r,
        c_in=0.0,
        c_out=0.0,
        c_int=c,
    )

    return switch


def compute_switchbox_timing_model(switchbox, timing_data):
    """
    Processes switchbox timing data.

    The timing data is provided in a form of delays for each mux edge (path
    from its input pin to the output pin). The delay varies with number of
    active loads of the source.

    This data is used to compute driver resistances and load capacitances
    as well as constant propagation delays.

    The timing model assumes that each output of a mux has a certain resistance
    and constant propagation time. Then, every load has a capacitance which is
    connected when it is active. All capacitances are identical. The input
    timing data does not allow to distinguish between them. Additionally, each
    load can have a constant propagation delay.

    For multiplexers that are driver by switchbox inputs, fake drivers are
    assumed solely for the purpose of the timing model.
    """

    # A helper struct
    Timing = namedtuple("Timing", "driver_r driver_tdel sink_c sink_tdel")

    # Delay scaling factor
    FACTOR = 1.0

    # Error threshold (for reporting) in ns
    ERROR_THRESHOLD = 0.4 * 1e-9

    # Build a map of sinks for each driver
    # For internal drivers key = (stage_id, switch_id, mux_id)
    # For external drivers key = (stage_id, input_name)
    sink_map = defaultdict(lambda: [])

    for connection in switchbox.connections:
        src = connection.src
        dst = connection.dst

        dst_key = (dst.stage_id, dst.switch_id, dst.mux_id, dst.pin_id)
        src_key = (src.stage_id, src.switch_id, src.mux_id)

        sink_map[src_key].append(dst_key)

    for pin in switchbox.inputs.values():
        for loc in pin.locs:
            dst_key = (loc.stage_id, loc.switch_id, loc.mux_id, loc.pin_id)
            src_key = (loc.stage_id, pin.name)

            sink_map[src_key].append(dst_key)

    # Compute timing model for each driver
    driver_timing = {}
    for driver, sinks in sink_map.items():
        # Collect timing data for each sink edge
        edge_timings = {}
        for stage_id, switch_id, mux_id, pin_id in sinks:
            # Try getting timing data. If not found then probably we are
            # computing timing for VCC or GND input.
            try:
                data = timing_data[stage_id][switch_id][mux_id][pin_id]
            except KeyError:
                continue

            # Sanity check. The number of load counts must be equal to the
            # number of sinks for the driver.
            assert len(data) == len(sinks)

            # Take the worst case (max), convert ns to seconds.
            data = {n: max(d) * 1e-9 for n, d in data.items()}

            # Store
            key = (stage_id, switch_id, mux_id, pin_id)
            edge_timings[key] = data

        # No timing data, probably it is a VCC or GND input
        if not len(edge_timings):
            continue

        # Compute linear regression for each sink data
        coeffs = {}
        for sink in sinks:
            xs = sorted(edge_timings[sink].keys())
            ys = [edge_timings[sink][x] for x in xs]

            a, b = linear_regression(xs, ys)

            # Cannot have a < 0 (decreasing relation). If such thing happens
            # force the regression line to be flat.
            if a < 0.0:
                print(
                    "WARNING: For '{} {}' the delay model slope is negative! (a={:.2e})".format(switchbox.type, sink, a)
                )
                a = 0.0

            # Cannot have any delay higher than the model. Check if all delays
            # lie below the regression line and if not then shift the line up
            # accordingly.
            for x, y in zip(xs, ys):
                t = a * x + b
                if y > t:
                    b += y - t

            coeffs[sink] = (a, b)

        # Assumed driver resistance [ohm]
        driver_r = 1.0

        # Compute driver's Tdel
        driver_tdel = min([cfs[1] for cfs in coeffs.values()])

        # Compute per-sink Tdel
        sink_tdel = {s: cfs[1] - driver_tdel for s, cfs in coeffs.items()}

        # Compute sink capacitance. Since we have multiple edge timings that
        # should yield the same capacitance, compute one for each timing and
        # then choose the worst case (max).
        sink_cs = {s: (cfs[0] / (FACTOR * driver_r) - sink_tdel[s]) for s, cfs in coeffs.items()}
        sink_c = max(sink_cs.values())

        # Sanity check
        assert sink_c >= 0.0, (switchbox.type, sink, sink_c)

        # Compute error of the delay model
        for sink in sinks:
            # Compute for this sink
            error = {}
            for n, true_delay in edge_timings[sink].items():
                model_delay = driver_tdel + FACTOR * driver_r * sink_c * n + sink_tdel[sink]
                error[n] = true_delay - model_delay

            max_error = max([abs(e) for e in error.values()])

            # Report the error
            if max_error > ERROR_THRESHOLD:
                print("WARNING: Error of the timing model of '{} {}' is too high:".format(switchbox.type, sink))
                print("--------------------------------------------")
                print("| # loads | actual   | model    | error    |")
                print("|---------+----------+----------+----------|")

                for n in edge_timings[sink].keys():
                    print(
                        "| {:<8}| {:<9.3f}| {:<9.3f}| {:<9.3f}|".format(
                            n, 1e9 * edge_timings[sink][n], 1e9 * (edge_timings[sink][n] - error[n]), 1e9 * error[n]
                        )
                    )

                print("--------------------------------------------")
                print("")

        # Store the data
        driver_timing[driver] = Timing(
            driver_r=driver_r, driver_tdel=driver_tdel, sink_tdel={s: d for s, d in sink_tdel.items()}, sink_c=sink_c
        )

    return driver_timing, sink_map


def populate_switchbox_timing(switchbox, driver_timing, sink_map, vpr_switches):
    """
    Populates the switchbox timing model by annotating its muxes with the timing
    data. Creates new VPR switches with required parameters or uses existing
    ones if already created.
    """

    # Populate timing data to the switchbox
    for driver, timing in driver_timing.items():
        # Driver VPR switch
        driver_vpr_switch = create_vpr_switch(
            type="mux",
            tdel=timing.driver_tdel,
            r=timing.driver_r,
            c=0.0,
        )

        driver_vpr_switch = add_named_item(vpr_switches, driver_vpr_switch, driver_vpr_switch.name)

        # Annotate all driver's edges
        for sink in sink_map[driver]:
            stage_id, switch_id, mux_id, pin_id = sink

            # Sink VPR switch
            sink_vpr_switch = create_vpr_switch(
                type="mux",
                tdel=timing.sink_tdel[sink],
                r=0.0,
                c=timing.sink_c,
            )

            sink_vpr_switch = add_named_item(vpr_switches, sink_vpr_switch, sink_vpr_switch.name)

            # Get the mux
            stage = switchbox.stages[stage_id]
            switch = stage.switches[switch_id]
            mux = switch.muxes[mux_id]

            assert pin_id not in mux.timing

            mux.timing[pin_id] = MuxEdgeTiming(
                driver=DriverTiming(tdel=timing.driver_tdel, r=timing.driver_r, vpr_switch=driver_vpr_switch.name),
                sink=SinkTiming(tdel=timing.sink_tdel, c=timing.sink_c, vpr_switch=sink_vpr_switch.name),
            )


def copy_switchbox_timing(src_switchbox, dst_switchbox):
    """
    Copies all timing information from the source switchbox to the destination
    one.
    """

    # Mux timing
    for dst_stage, dst_switch, dst_mux in yield_muxes(dst_switchbox):
        src_stage = src_switchbox.stages[dst_stage.id]
        src_switch = src_stage.switches[dst_switch.id]
        src_mux = src_switch.muxes[dst_mux.id]

        dst_mux.timing = deepcopy(src_mux.timing)


# =============================================================================


def add_vpr_switches_for_cell(cell_type, cell_timings):
    """
    Creates VPR switches for IOPATH delays read from SDF file(s) for the given
    cell type.
    """

    # Filter timings for the cell
    timings = {k: v for k, v in cell_timings.items() if k.startswith(cell_type)}

    # Add VPR switches
    vpr_switches = {}
    for celltype, cell_data in timings.items():
        for instance, inst_data in cell_data.items():
            # Add IOPATHs
            for timing, timing_data in inst_data.items():
                if timing_data["type"].lower() != "iopath":
                    continue

                # Get data
                name = "{}.{}.{}.{}".format(cell_type, instance, timing_data["from_pin"], timing_data["to_pin"])
                tdel = timing_data["delay_paths"]["slow"]["avg"]

                # Add the switch
                sw = VprSwitch(
                    name=name,
                    type="mux",
                    t_del=tdel,
                    r=0.0,
                    c_in=0.0,
                    c_out=0.0,
                    c_int=0.0,
                )
                vpr_switches[sw.name] = sw

    return vpr_switches
