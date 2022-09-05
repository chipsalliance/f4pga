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
import argparse

import lxml.etree as ET

from f4pga.utils.quicklogic.pp3.data_structs import SwitchboxPinType
from f4pga.utils.quicklogic.pp3.data_import import import_data

# =============================================================================


def fixup_pin_name(name):
    return name.replace("[", "").replace("]", "")


def switchbox_to_dot(switchbox, stage_types=("STREET", "HIGHWAY")):
    dot = []

    TYPE_TO_COLOR = {
        SwitchboxPinType.UNSPEC: "#C0C0C0",
        SwitchboxPinType.LOCAL: "#C0C0FF",
        SwitchboxPinType.HOP: "#FFFFC0",
        SwitchboxPinType.CONST: "#FFC0C0",
        SwitchboxPinType.GCLK: "#C0FFC0",
    }

    # Add header
    dot.append("digraph {} {{".format(switchbox.type))
    dot.append('  graph [nodesep="1.0", ranksep="20"];')
    dot.append('  splines = "false";')
    dot.append("  rankdir = LR;")
    dot.append("  margin = 20;")
    dot.append("  node [shape=record, style=filled, fillcolor=white];")

    stage_ids_to_show = set([s.id for s in switchbox.stages.values() if s.type in stage_types])

    # Top-level inputs
    dot.append("  subgraph cluster_inputs {")
    dot.append("    node [shape=ellipse, style=filled];")
    dot.append('    label="Inputs";')

    for pin in switchbox.inputs.values():
        stage_ids = set([loc.stage_id for loc in pin.locs])
        if not len(stage_ids & stage_ids_to_show):
            continue

        color = TYPE_TO_COLOR.get(pin.type, "#C0C0C0")
        name = "input_{}".format(fixup_pin_name(pin.name))
        dot.append('    {} [rank=0, label="{}", fillcolor="{}"];'.format(name, pin.name, color))

    dot.append("  }")

    # Top-level outputs
    dot.append("  subgraph cluster_outputs {")
    dot.append("    node [shape=ellipse, style=filled];")
    dot.append('    label="Outputs";')

    rank = max(switchbox.stages.keys()) + 1

    for pin in switchbox.outputs.values():
        stage_ids = set([loc.stage_id for loc in pin.locs])
        if not len(stage_ids & stage_ids_to_show):
            continue

        color = TYPE_TO_COLOR[pin.type]
        name = "output_{}".format(fixup_pin_name(pin.name))
        dot.append('    {} [rank={}, label="{}", fillcolor="{}"];'.format(name, rank, pin.name, color))

    dot.append("  }")

    # Stages
    for stage in switchbox.stages.values():

        if stage.type not in stage_types:
            continue

        rank = stage.id + 1

        dot.append("  subgraph cluster_st{} {{".format(stage.id))
        dot.append("    label=\"Stage #{} '{}'\";".format(stage.id, stage.type))
        dot.append('    bgcolor="#D0D0D0"')

        # Switch
        for switch in stage.switches.values():
            dot.append("    subgraph cluster_st{}_sw{} {{".format(stage.id, switch.id))
            dot.append('      label="Switch #{}";'.format(switch.id))
            dot.append('    bgcolor="#F0F0F0"')

            # Mux
            for mux in switch.muxes.values():
                inputs = sorted(mux.inputs.values(), key=lambda p: p.id)

                mux_l = "Mux #{}".format(mux.id)
                inp_l = "|".join(["<i{}> {}. {}".format(p.id, p.id, p.name) for p in inputs])
                out_l = "<o{}> {}. {}".format(mux.output.id, mux.output.id, mux.output.name)
                label = "{}|{{{{{}}}|{{{}}}}}".format(mux_l, inp_l, out_l)
                name = "st{}_sw{}_mx{}".format(stage.id, switch.id, mux.id)

                dot.append('      {} [rank="{}", label="{}"];'.format(name, rank, label))

            dot.append("    }")

        dot.append("  }")

    # Internal connections
    for conn in switchbox.connections:

        if switchbox.stages[conn.src.stage_id].type not in stage_types:
            continue
        if switchbox.stages[conn.dst.stage_id].type not in stage_types:
            continue

        src_node = "st{}_sw{}_mx{}".format(conn.src.stage_id, conn.src.switch_id, conn.src.mux_id)
        src_port = "o{}".format(conn.src.pin_id)
        dst_node = "st{}_sw{}_mx{}".format(conn.dst.stage_id, conn.dst.switch_id, conn.dst.mux_id)
        dst_port = "i{}".format(conn.dst.pin_id)

        dot.append("  {}:{} -> {}:{};".format(src_node, src_port, dst_node, dst_port))

    # Input pin connections
    for pin in switchbox.inputs.values():
        src_node = "input_{}".format(fixup_pin_name(pin.name))

        for loc in pin.locs:

            if switchbox.stages[loc.stage_id].type not in stage_types:
                continue

            dst_node = "st{}_sw{}_mx{}".format(loc.stage_id, loc.switch_id, loc.mux_id)
            dst_port = "i{}".format(loc.pin_id)

            dot.append("  {} -> {}:{};".format(src_node, dst_node, dst_port))

    # Output pin connections
    for pin in switchbox.outputs.values():
        dst_node = "output_{}".format(fixup_pin_name(pin.name))

        for loc in pin.locs:

            if switchbox.stages[loc.stage_id].type not in stage_types:
                continue

            src_node = "st{}_sw{}_mx{}".format(loc.stage_id, loc.switch_id, loc.mux_id)
            src_port = "o{}".format(loc.pin_id)

            dot.append("  {}:{} -> {};".format(src_node, src_port, dst_node))

    # Footer
    dot.append("}")
    return "\n".join(dot)


# =============================================================================


def main():

    # Parse arguments
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)

    parser.add_argument("i", type=str, help="Quicklogic 'TechFile' file")
    parser.add_argument(
        "--stages", type=str, default="STREET", help="Comma-separated list of stage types to view (def. STREET)"
    )

    args = parser.parse_args()

    # Read and parse the XML file
    xml_tree = ET.parse(args.i)
    xml_root = xml_tree.getroot()

    # Load data
    data = import_data(xml_root)
    switchbox_types = data["switchbox_types"]

    # Generate DOT files with switchbox visualizations
    for switchbox in switchbox_types.values():
        fname = "sbox_{}.dot".format(switchbox.type)
        with open(fname, "w") as fp:
            fp.write(switchbox_to_dot(switchbox, args.stages.split(",")))


# =============================================================================

if __name__ == "__main__":
    main()
