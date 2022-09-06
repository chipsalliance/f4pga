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


from collections import defaultdict

from f4pga.aux.utils.quicklogic.pp3.data_structs import PinDirection, ConnectionType
from f4pga.aux.utils.quicklogic.pp3.utils import yield_muxes
from f4pga.aux.utils.quicklogic.pp3.rr_utils import add_node, connect


class SwitchboxModel(object):
    """
    Represents a model of connectivity of a concrete instance of a switchbox.
    """

    def __init__(self, graph, loc, phy_loc, switchbox):
        self.graph = graph
        self.loc = loc
        self.phy_loc = phy_loc
        self.switchbox = switchbox

        self.fixed_muxsels = set()
        self.fixed_muxes = None

        self.mux_input_to_node = {}
        self.mux_output_to_node = {}

        self.input_to_node = {}

    @staticmethod
    def get_metadata_for_mux(loc, stage, switch_id, mux_id, pin_id):
        """
        Formats fasm features for the given edge representin a switchbox mux.
        Returns a list of fasm features.
        """
        metadata = []

        # Format prefix
        prefix = "X{}Y{}.ROUTING".format(loc.x, loc.y)

        # A mux in the HIGHWAY stage
        if stage.type == "HIGHWAY":
            feature = "I_highway.IM{}.I_pg{}".format(switch_id, pin_id)

        # A mux in the STREET stage
        elif stage.type == "STREET":
            feature = "I_street.Isb{}{}.I_M{}.I_pg{}".format(stage.id + 1, switch_id + 1, mux_id, pin_id)

        else:
            assert False, stage

        metadata.append(".".join([prefix, feature]))
        return metadata

    @staticmethod
    def get_chan_dirs_for_stage(stage):
        """
        Returns channel directions for inputs and outputs of a stage.
        """

        if stage.type == "HIGHWAY":
            return "Y", "X"

        elif stage.type == "STREET":
            dir_inp = "Y" if (stage.id % 2) else "X"
            dir_out = "X" if (stage.id % 2) else "Y"
            return dir_inp, dir_out

        else:
            assert False, stage.type

    @staticmethod
    def get_connection(switchbox, src, dst):
        """
        Returns the SwitchboxConnection object that spans two muxes given their
        locations. Parameters src and dst should be tuples containing:
        (stage_id, switch_id, mux_id)
        """

        for connection in switchbox.connections:
            c_src = (connection.src.stage_id, connection.src.switch_id, connection.src.mux_id)
            c_dst = (connection.dst.stage_id, connection.dst.switch_id, connection.dst.mux_id)

            if c_src == src and c_dst == dst:
                return connection

        return None

    @staticmethod
    def get_switchbox_routes(switchbox, out_name, inp_name):
        """
        Returns a list of routes inside the switchbox that connect the given
        output pin with the given input pin.

        Returns a list of lists. Each inner list contain tuples with
        (stage_id, switch_id, mux_id, pin_id)
        """

        # Route list
        routes = []

        def walk(ctx, target_name, route=None):
            """
            An inner recursive walk function. Walks from a location within
            the switchbox until the target input pin is reached.
            """

            # Copy/create the route list
            if route is None:
                route = []
            else:
                route = list(route)

            # Add this mux
            route.append(ctx)

            # Get the mux object
            stage_id, switch_id, mux_id = ctx

            stage = switchbox.stages[stage_id]
            switch = stage.switches[switch_id]
            mux = switch.muxes[mux_id]

            # Get its input connections
            connections = {}
            for connection in switchbox.connections:
                is_stage_id = connection.dst.stage_id == stage_id
                is_switch_id = connection.dst.switch_id == switch_id
                is_mux_id = connection.dst.mux_id == mux_id
                if is_stage_id and is_switch_id and is_mux_id:
                    connections[connection.dst.pin_id] = connection

            # Expand all its inputs
            for pin_id, pin in mux.inputs.items():
                # An input goes to another mux, expand it
                if pin.name is None and pin_id in connections:
                    connection = connections[pin_id]

                    next_ctx = (
                        connection.src.stage_id,
                        connection.src.switch_id,
                        connection.src.mux_id,
                    )
                    walk(next_ctx, target_name, route)

                # This is a switchbox input
                elif pin.name is not None:
                    # We've hit the target
                    if pin.name == target_name:
                        # Append the current mux and its selection
                        final_route = list(route)
                        final_route[-1] = tuple(list(final_route[-1]) + [pin_id])

                        # Trace the route back, append mux selections
                        for i in range(len(final_route) - 1):
                            dst = final_route[i][:3]
                            src = final_route[i + 1][:3]

                            connection = SwitchboxModel.get_connection(switchbox, src, dst)

                            sel = connection.dst.pin_id
                            final_route[i] = tuple(list(final_route[i]) + [sel])

                        routes.append(final_route)

                # Should not happen
                else:
                    assert False, pin

        # Get the output pin
        pin = switchbox.outputs[out_name]
        assert len(pin.locs) == 1
        loc = pin.locs[0]

        # Walk from the output, collect routes
        ctx = (
            loc.stage_id,
            loc.switch_id,
            loc.mux_id,
        )
        walk(ctx, inp_name)

        return routes

    def _create_muxes(self):
        """
        Creates nodes for muxes and internal edges within them. Annotates the
        internal edges with fasm data.

        Builds maps of muxs' inputs and outpus to VPR nodes.
        """

        # Build mux driver timing map. Assign each mux output its timing data
        driver_timing = {}
        for connection in self.switchbox.connections:
            src = connection.src

            stage = self.switchbox.stages[src.stage_id]
            switch = stage.switches[src.switch_id]
            mux = switch.muxes[src.mux_id]
            pin = mux.inputs[src.pin_id]

            if pin.id not in mux.timing:
                continue

            timing = mux.timing[pin.id].driver

            key = (src.stage_id, src.switch_id, src.mux_id)
            if key in driver_timing:
                assert driver_timing[key] == timing, (self.loc, key, driver_timing[key], timing)
            else:
                driver_timing[key] = timing

        # Create muxes
        segment_id = self.graph.get_segment_id_from_name("sbox")

        for stage, switch, mux in yield_muxes(self.switchbox):
            dir_inp, dir_out = self.get_chan_dirs_for_stage(stage)

            # Output node
            key = (stage.id, switch.id, mux.id)
            assert key not in self.mux_output_to_node

            out_node = add_node(self.graph, self.loc, dir_out, segment_id)
            self.mux_output_to_node[key] = out_node

            # Intermediate output node
            int_node = add_node(self.graph, self.loc, dir_out, segment_id)

            # Get switch id for the switch assigned to the driver. If
            # there is none then use the delayless switch. Probably the
            # driver is connected to a const.
            if key in driver_timing:
                switch_id = self.graph.get_switch_id(driver_timing[key].vpr_switch)
            else:
                switch_id = self.graph.get_delayless_switch_id()

            # Output driver edge
            connect(
                self.graph,
                int_node,
                out_node,
                switch_id=switch_id,
                segment_id=segment_id,
            )

            # Input nodes + mux edges
            for pin in mux.inputs.values():
                key = (stage.id, switch.id, mux.id, pin.id)
                assert key not in self.mux_input_to_node

                # Input node
                inp_node = add_node(self.graph, self.loc, dir_inp, segment_id)
                self.mux_input_to_node[key] = inp_node

                # Get mux metadata
                metadata = self.get_metadata_for_mux(self.phy_loc, stage, switch.id, mux.id, pin.id)

                if len(metadata):
                    meta_name = "fasm_features"
                    meta_value = "\n".join(metadata)
                else:
                    meta_name = None
                    meta_value = ""

                # Get switch id for the switch assigned to the mux edge. If
                # there is none then use the delayless switch. Probably the
                # edge is connected to a const.
                if pin.id in mux.timing:
                    switch_id = self.graph.get_switch_id(mux.timing[pin.id].sink.vpr_switch)
                else:
                    switch_id = self.graph.get_delayless_switch_id()

                # Mux switch with appropriate timing and fasm metadata
                connect(
                    self.graph,
                    inp_node,
                    int_node,
                    switch_id=switch_id,
                    segment_id=segment_id,
                    meta_name=meta_name,
                    meta_value=meta_value,
                )

    def _connect_muxes(self):
        """
        Creates VPR edges that connects muxes within the switchbox.
        """

        segment_id = self.graph.get_segment_id_from_name("sbox")
        switch_id = self.graph.get_switch_id("short")

        # Add internal connections between muxes.
        for connection in self.switchbox.connections:
            src = connection.src
            dst = connection.dst

            # Check
            assert src.pin_id == 0, src
            assert src.pin_direction == PinDirection.OUTPUT, src

            # Get the input node
            key = (dst.stage_id, dst.switch_id, dst.mux_id, dst.pin_id)
            dst_node = self.mux_input_to_node[key]

            # Get the output node
            key = (src.stage_id, src.switch_id, src.mux_id)
            src_node = self.mux_output_to_node[key]

            # Connect
            connect(self.graph, src_node, dst_node, switch_id=switch_id, segment_id=segment_id)

    def _create_input_drivers(self):
        """
        Creates VPR nodes and edges that model input connectivity of the
        switchbox.
        """

        # Create a driver map containing all mux pin locations that are
        # connected to a driver. The map is indexed by (pin_name, vpr_switch)
        # and groups togeather inputs that should be driver by a specific
        # switch due to the timing model.
        driver_map = defaultdict(lambda: [])

        for pin in self.switchbox.inputs.values():
            for loc in pin.locs:
                stage = self.switchbox.stages[loc.stage_id]
                switch = stage.switches[loc.switch_id]
                mux = switch.muxes[loc.mux_id]
                pin = mux.inputs[loc.pin_id]

                if pin.id not in mux.timing:
                    vpr_switch = None
                else:
                    vpr_switch = mux.timing[pin.id].driver.vpr_switch

                key = (pin.name, vpr_switch)
                driver_map[key].append(loc)

        # Create input nodes for each input pin
        segment_id = self.graph.get_segment_id_from_name("sbox")

        for pin in self.switchbox.inputs.values():
            node = add_node(self.graph, self.loc, "Y", segment_id)

            assert pin.name not in self.input_to_node, pin.name
            self.input_to_node[pin.name] = node

        # Create driver nodes, connect everything
        for (pin_name, vpr_switch), locs in driver_map.items():
            # Create the driver node
            drv_node = add_node(self.graph, self.loc, "X", segment_id)

            # Connect input node to the driver node. Use the switch with timing.
            inp_node = self.input_to_node[pin_name]

            # Get switch id for the switch assigned to the driver. If
            # there is none then use the delayless switch. Probably the
            # driver is connected to a const.
            if vpr_switch is not None:
                switch_id = self.graph.get_switch_id(vpr_switch)
            else:
                switch_id = self.graph.get_delayless_switch_id()

            # Connect
            connect(self.graph, inp_node, drv_node, switch_id=switch_id, segment_id=segment_id)

            # Now connect the driver node with its loads
            switch_id = self.graph.get_switch_id("short")
            for loc in locs:
                key = (loc.stage_id, loc.switch_id, loc.mux_id, loc.pin_id)
                dst_node = self.mux_input_to_node[key]

                connect(self.graph, drv_node, dst_node, switch_id=switch_id, segment_id=segment_id)

    def build(self):
        """
        Build the switchbox model by creating and adding its nodes and edges
        to the RR graph.
        """

        # TODO: FIXME: When a switchbox model contains fixed muxes only they
        # should be removed and the rest of the switchbox should be added
        # to the rr graph. For now if there is any fixed mux, remove the
        # whole switchbox.
        if len(self.fixed_muxsels):
            # A list of muxes to avoid
            self.fixed_muxes = set([f[:3] for f in self.fixed_muxsels])

            print(
                "Switchbox model '{}' at '{}' contains '{}' fixed muxes.".format(
                    self.switchbox.type, self.loc, len(self.fixed_muxes)
                )
            )
            return

        # Create and connect muxes
        self._create_muxes()
        self._connect_muxes()

        # Create and connect input drivers models
        self._create_input_drivers()

    def get_input_node(self, pin_name):
        """
        Returns a VPR node associated with the given input of the switchbox
        """
        return self.input_to_node[pin_name]

    def get_output_node(self, pin_name):
        """
        Returns a VPR node associated with the given output of the switchbox
        """

        # Get the output pin
        pin = self.switchbox.outputs[pin_name]

        assert len(pin.locs) == 1
        loc = pin.locs[0]

        # Return its node
        key = (loc.stage_id, loc.switch_id, loc.mux_id)
        return self.mux_output_to_node[key]


# =============================================================================


class QmuxSwitchboxModel(SwitchboxModel):
    """
    Represents a model of connectivity of a concrete instance of a switchbox
    located at a QMUX tile
    """

    def __init__(self, graph, loc, phy_loc, switchbox, qmux_cells, connections):
        super().__init__(graph, loc, phy_loc, switchbox)

        self.qmux_cells = qmux_cells
        self.connections = connections

        self.ctrl_routes = {}

    def _find_control_routes(self):
        """ """
        PINS = (
            "IS0",
            "IS1",
        )

        for cell in self.qmux_cells.values():
            # Get IS0 and IS1 connection endpoints
            eps = {}
            for connection in self.connections:
                if connection.dst.type == ConnectionType.CLOCK:
                    dst_cell, dst_pin = connection.dst.pin.split(".")

                    if dst_cell == cell.name and dst_pin in PINS:
                        eps[dst_pin] = connection.src

            # Find all routes for IS0 and IS1 pins that go to GND and VCC
            routes = {}
            for pin in PINS:
                # Find the routes
                vcc_routes = self.get_switchbox_routes(self.switchbox, eps[pin].pin, "VCC")
                gnd_routes = self.get_switchbox_routes(self.switchbox, eps[pin].pin, "GND")

                routes[pin] = {"VCC": vcc_routes, "GND": gnd_routes}

            # Store
            self.ctrl_routes[cell.name] = routes

    def build(self):
        """
        Builds the QMUX switchbox model
        """

        # Find routes inside the switchbox for GMUX control pins
        self._find_control_routes()

        # Filter routes so GND routes go through stage 2, switch 0 and VCC
        # routes go through stage 2, switch 1.
        for cell_name, cell_routes in self.ctrl_routes.items():
            for pin, pin_routes in cell_routes.items():
                for net, net_routes in pin_routes.items():
                    routes = []
                    for route in net_routes:
                        # Assume 3-stage switchbox
                        assert len(route) == 3, "FIXME: Assuming 3-stage switchbox!"

                        if route[1][1] == 0 and net == "GND":
                            routes.append(route)
                        if route[1][1] == 1 and net == "VCC":
                            routes.append(route)

                    pin_routes[net] = routes

    def get_input_node(self, pin_name):
        return None

    def get_output_node(self, pin_name):
        return None
