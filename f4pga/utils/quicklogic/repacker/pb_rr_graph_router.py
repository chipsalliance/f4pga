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
"""
This file implements a simple graph router used for complex block routing
graphs.
"""

import logging

from f4pga.utils.quicklogic.repacker.pb_rr_graph import NodeType

# =============================================================================


class Net:
    """
    This class represents a net for the router. It holds the driver (source)
    node as well as all sink node ids.
    """

    def __init__(self, name):
        self.name = name

        self.sources = set()
        self.sinks = set()

        self.is_routed = False

    def __str__(self):
        return "{}, {} sources, max_fanout={}, {}".format(
            self.name, len(self.sources), len(self.sinks), "routed" if self.is_routed else "unrouted"
        )


# =============================================================================


class Router:
    """
    Simple graph router.

    Currently the routed does a greedy depth-first routing. Each time a path
    from a sink to a source is found it gets immediately annotated with nets.
    """

    def __init__(self, graph):
        self.graph = graph
        self.nets = {}

        # Discover nets from the graph
        self.discover_nets()

    def discover_nets(self):
        """
        Scans the graph looking for nets
        """

        # TODO: For now look for nets only assuming that all of them are
        # unrouted.
        sources = {}
        sinks = {}

        for node in self.graph.nodes.values():

            if node.type not in [NodeType.SOURCE, NodeType.SINK]:
                continue

            # No net
            if node.net is None:
                continue

            # Got a source
            if node.type == NodeType.SOURCE:
                if node.net not in sources:
                    sources[node.net] = set()
                sources[node.net].add(node.id)

            # Got a sink
            elif node.type == NodeType.SINK:
                if node.net not in sinks:
                    sinks[node.net] = set()
                sinks[node.net].add(node.id)

        # Make nets
        nets = set(sinks.keys()) | set(sources.keys())
        for net_name in nets:

            net = Net(net_name)

            # A net may or may not have a source node(s). If there are no
            # sources then one will be created during routing when a route
            # reaches a node of the top-level CLB.
            if net_name in sources:
                net.sources = sources[net_name]

            # A net may or may not have at leas one sink node. If there are
            # no sinks then no routing will be done.
            if net_name in sinks:
                net.sinks = sinks[net_name]

            self.nets[net_name] = net

        # DEBUG
        logging.debug("   Nets:")
        keys = sorted(list(self.nets.keys()))
        for key in keys:
            logging.debug("    " + str(self.nets[key]))

    def route_net(self, net, debug=False):
        """
        Routes a single net.
        """

        top_level_sources = set()

        def walk_depth_first(node, curr_route=None):

            # FIXME: Two possible places for optimization:
            # - create an edge lookup list indexed by dst node ids
            # - do not copy the current route list for each recursion level

            # Track the route
            if not curr_route:
                curr_route = []
            curr_route.append(node.id)

            # We've hit a node of the same net. Finish.
            if node.type in [NodeType.SOURCE, NodeType.PORT]:
                if node.net == net.name:
                    return curr_route

            # The node is aleady occupied by a different net
            if node.net is not None:
                if node.net != net.name:
                    return None

            # This node is a free source node. If it is a top-level source then
            # store it.
            if node.type == NodeType.SOURCE and node.net is None:
                if node.path.count(".") == 1:
                    top_level_sources.add(node.id)

            # Check all incoming edges
            for edge in self.graph.edges:
                if edge.dst_id == node.id:

                    # Recurse
                    next_node = self.graph.nodes[edge.src_id]
                    route = walk_depth_first(next_node, list(curr_route))

                    # We have a route, terminate
                    if route:
                        return route

            return None

        # Search for a route
        logging.debug("   " + net.name)

        # This net has no sinks. Remove annotation from the source nodes
        if not net.sinks:
            for node_id in net.sources:
                node = self.graph.nodes[node_id]
                node.net = None

        # Route all sinks to any of the net sources
        for sink in net.sinks:

            # Find the route
            node = self.graph.nodes[sink]

            top_level_sources = set()
            route = walk_depth_first(node)

            # No route found. Check if we have some free top-level ports that
            # we can use.
            if not route and top_level_sources:

                # Use the frist one
                top_node_id = next(iter(top_level_sources))
                top_node = self.graph.nodes[top_node_id]
                top_node.net = net.name

                # Retry
                route = walk_depth_first(node)

            # No route found
            if not route:
                logging.critical("    No route found!")

                # DEBUG
                if debug:
                    with open("unrouted.dot", "w") as fp:
                        fp.write(self.graph.dump_dot(color_by="net", highlight_nodes=net.sources | set([sink])))

                # Raise an exception
                raise RuntimeError(
                    "Unroutable net '{}' from {} to {}".format(
                        net.name, [self.graph.nodes[node_id] for node_id in net.sources], self.graph.nodes[sink]
                    )
                )

            # Annotate all nodes of the route
            for node_id in route:
                self.graph.nodes[node_id].net = net.name

        # Success
        net.is_routed = True

    def route_nets(self, nets=None, debug=False):
        """
        Routes net with specified names or all nets if no names are given.
        """

        # Use all if explicit list not provided
        if nets is None:
            nets = sorted(list(self.nets.keys()))

        # Route nets
        for net_name in nets:
            self.route_net(self.nets[net_name], debug=debug)
