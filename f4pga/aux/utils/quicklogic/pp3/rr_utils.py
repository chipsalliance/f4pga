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


from f4pga.aux.utils.quicklogic.pp3.data_structs import Loc

from lib.rr_graph import tracks
import lib.rr_graph.graph2 as rr


def add_track(graph, track, segment_id, node_timing=None):
    """
    Adds a track to the graph. Returns the node object representing the track
    node.
    """

    if node_timing is None:
        node_timing = rr.NodeTiming(r=0.0, c=0.0)

    node_id = graph.add_track(track, segment_id, timing=node_timing)
    node = graph.nodes[-1]
    assert node.id == node_id

    return node


def add_node(graph, loc, direction, segment_id):
    """
    Adds a track of length 1 to the graph. Returns the node object
    """

    return add_track(
        graph,
        tracks.Track(
            direction=direction,
            x_low=loc.x,
            x_high=loc.x,
            y_low=loc.y,
            y_high=loc.y,
        ),
        segment_id,
    )


def add_edge(graph, src_node_id, dst_node_id, switch_id, meta_name=None, meta_value=""):
    """
    Adds an edge to the routing graph. If the given switch corresponds to a
    "pass" type switch then adds two edges going both ways.
    """

    # Sanity check
    assert src_node_id != dst_node_id, (src_node_id, dst_node_id, switch_id, meta_name, meta_value)

    # Connect src to dst
    graph.add_edge(src_node_id, dst_node_id, switch_id, meta_name, meta_value)

    # Check if the switch is of the "pass" type. If so then add an edge going
    # in the opposite way.
    switch = graph.switch_map[switch_id]
    if switch.type in [rr.SwitchType.SHORT, rr.SwitchType.PASS_GATE]:
        graph.add_edge(dst_node_id, src_node_id, switch_id, meta_name, meta_value)


# =============================================================================


def node_joint_location(node_a, node_b):
    """
    Given two VPR nodes returns a location of the point where they touch each
    other.
    """

    loc_a1 = Loc(node_a.loc.x_low, node_a.loc.y_low, 0)
    loc_a2 = Loc(node_a.loc.x_high, node_a.loc.y_high, 0)

    loc_b1 = Loc(node_b.loc.x_low, node_b.loc.y_low, 0)
    loc_b2 = Loc(node_b.loc.x_high, node_b.loc.y_high, 0)

    if loc_a1 == loc_b1:
        return loc_a1
    if loc_a1 == loc_b2:
        return loc_a1
    if loc_a2 == loc_b1:
        return loc_a2
    if loc_a2 == loc_b2:
        return loc_a2

    assert False, (node_a, node_b)


def connect(graph, src_node, dst_node, switch_id=None, segment_id=None, meta_name=None, meta_value=""):
    """
    Connect two VPR nodes in a way that certain rules are obeyed.

    The rules are:
    - a CHANX cannot connect directly to a CHANY and vice versa,
    - a CHANX cannot connect to an IPIN facing left or right,
    - a CHANY cannot connect to an IPIN facting top or bottom,
    - an OPIN facing left or right cannot connect to a CHANX,
    - an OPIN facing top or bottom cannot connect to a CHANY

    Whenever a rule is not met then the connection is made through a padding
    node:

    src -> [delayless] -> pad -> [desired switch] -> dst

    Otherwise the connection is made directly

    src -> [desired switch] -> dst

    The influence of whether the rules are obeyed or not on the actual VPR
    behavior is unclear.
    """

    # Use the default delayless switch if none is given
    if switch_id is None:
        switch_id = graph.get_delayless_switch_id()

    # Determine which segment to use if none given
    if segment_id is None:
        # If the source is IPIN/OPIN then use the same segment as used by
        # the destination.
        # If the destination is IPIN/OPIN then do the opposite.
        # Finally if both are CHANX/CHANY then use the source's segment.

        if src_node.type in [rr.NodeType.IPIN, rr.NodeType.OPIN]:
            segment_id = dst_node.segment.segment_id
        elif dst_node.type in [rr.NodeType.IPIN, rr.NodeType.OPIN]:
            segment_id = src_node.segment.segment_id
        else:
            segment_id = src_node.segment.segment_id

    # CHANX to CHANY or vice-versa
    chanx_to_chany = src_node.type == rr.NodeType.CHANX and dst_node.type == rr.NodeType.CHANY
    chany_to_chanx = src_node.type == rr.NodeType.CHANY and dst_node.type == rr.NodeType.CHANX
    chany_to_chany = src_node.type == rr.NodeType.CHANY and dst_node.type == rr.NodeType.CHANY
    chanx_to_chanx = src_node.type == rr.NodeType.CHANX and dst_node.type == rr.NodeType.CHANX
    if chany_to_chanx or chanx_to_chany:
        # Check loc
        node_joint_location(src_node, dst_node)

        # Connect directly
        add_edge(graph, src_node.id, dst_node.id, switch_id, meta_name, meta_value)

    # CHANX to CHANX or CHANY to CHANY
    elif chany_to_chany or chanx_to_chanx:
        loc = node_joint_location(src_node, dst_node)
        direction = "X" if src_node.type == rr.NodeType.CHANY else "Y"

        # Padding node
        pad_node = add_node(graph, loc, direction, segment_id)

        # Connect through the padding node
        add_edge(graph, src_node.id, pad_node.id, graph.get_delayless_switch_id())

        add_edge(graph, pad_node.id, dst_node.id, switch_id, meta_name, meta_value)

    # OPIN to CHANX/CHANY
    elif src_node.type == rr.NodeType.OPIN and dst_node.type in [rr.NodeType.CHANX, rr.NodeType.CHANY]:
        # All OPINs go right (towards +X)
        assert src_node.loc.side == tracks.Direction.RIGHT, src_node

        # Connected to CHANX
        if dst_node.type == rr.NodeType.CHANX:
            loc = node_joint_location(src_node, dst_node)

            # Padding node
            pad_node = add_node(graph, loc, "Y", segment_id)

            # Connect through the padding node
            add_edge(graph, src_node.id, pad_node.id, graph.get_delayless_switch_id())

            add_edge(graph, pad_node.id, dst_node.id, switch_id, meta_name, meta_value)

        # Connected to CHANY
        elif dst_node.type == rr.NodeType.CHANY:
            # Directly
            add_edge(graph, src_node.id, dst_node.id, switch_id, meta_name, meta_value)

        # Should not happen
        else:
            assert False, dst_node

    # CHANX/CHANY to IPIN
    elif dst_node.type == rr.NodeType.IPIN and src_node.type in [rr.NodeType.CHANX, rr.NodeType.CHANY]:
        # All IPINs go top (toward +Y)
        assert dst_node.loc.side == tracks.Direction.TOP, dst_node

        # Connected to CHANY
        if src_node.type == rr.NodeType.CHANY:
            loc = node_joint_location(src_node, dst_node)

            # Padding node
            pad_node = add_node(graph, loc, "X", segment_id)

            # Connect through the padding node
            add_edge(graph, src_node.id, pad_node.id, graph.get_delayless_switch_id())

            add_edge(graph, pad_node.id, dst_node.id, switch_id, meta_name, meta_value)

        # Connected to CHANX
        elif src_node.type == rr.NodeType.CHANX:
            # Directly
            add_edge(graph, src_node.id, dst_node.id, switch_id, meta_name, meta_value)

        # Should not happen
        else:
            assert False, dst_node

    # An unhandled case
    else:
        assert False, (src_node, dst_node)
