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
Creates a device library file
"""

import argparse
import sys
import csv
import os
import re
from collections import namedtuple
from collections import defaultdict
from datetime import date
import simplejson as json
import lxml.etree as ET

"""
Pin properties
name - pin_name
dir - direction (input/output)
used - specify 'yes' if user is using the pin else specify 'no'
clk - specify associate clock
"""
PinData = namedtuple("PinData", "name dir used clk")


def main():
    """
    Creates a device library file by getting data from given csv and xml file
    """
    parser = argparse.ArgumentParser(description="Creates a device library file.")
    parser.add_argument("--lib", "-l", "-L", type=str, default="qlf_k4n8.lib", help="The output device lib file")
    parser.add_argument("--lib_name", "-n", "-N", type=str, required=True, help="Specify library name")
    parser.add_argument(
        "--template_data_path",
        "-t",
        "-T",
        type=str,
        required=True,
        help="Specify path from where to pick template data for library creation",
    )
    parser.add_argument("--cell_name", "-m", "-M", type=str, required=True, help="Specify cell name")
    parser.add_argument("--csv", "-c", "-C", type=str, required=True, help="Input pin-map csv file")
    parser.add_argument("--xml", "-x", "-X", type=str, required=True, help="Input interface-mapping xml file")

    args = parser.parse_args()

    if not os.path.exists(args.template_data_path):
        print('Invalid template data path "{}" specified'.format(args.template_data_path), file=sys.stderr)
        sys.exit(1)

    csv_pin_data = defaultdict(set)
    assoc_clk = dict()
    with open(args.csv, newline="") as csvfile:
        reader = csv.DictReader(csvfile)
        for row in reader:
            # define properties for scalar pins
            scalar_port_names = vec_to_scalar(row["port_name"])
            for port in scalar_port_names:
                if port.find("F2A") != -1:
                    csv_pin_data["F2A"].add(port)
                elif port.find("A2F") != -1:
                    csv_pin_data["A2F"].add(port)
                if row["Associated Clock"] is not None:
                    assoc_clk[port] = row["Associated Clock"].strip()

    port_names = parse_xml(args.xml)
    create_lib(port_names, args.template_data_path, csv_pin_data, args.lib_name, args.lib, args.cell_name, assoc_clk)


# =============================================================================
def create_lib(port_names, template_data_path, csv_pin_data, lib_name, lib_file_name, cell_name, assoc_clk):
    """
    Create lib file
    """
    # Read header template file and populate lib file with this data
    curr_dir = os.path.dirname(os.path.abspath(__file__))

    common_lib_data = dict()
    common_lib_data_file = os.path.join(template_data_path, "common_lib_data.json")
    with open(common_lib_data_file) as fp:
        common_lib_data = json.load(fp)

    today = date.today()
    curr_date = today.strftime("%B %d, %Y")

    lib_header_tmpl = os.path.join(template_data_path, "lib_header_template.txt")
    header_templ_file = os.path.join(curr_dir, lib_header_tmpl)
    in_str = open(header_templ_file, "r").read()

    curr_str = in_str.replace("{lib_name}", lib_name)
    str_rep_date = curr_str.replace("{curr_date}", curr_date)
    str1 = str_rep_date.replace("{cell_name}", cell_name)

    a2f_pin_list = [None] * len(port_names["A2F"])
    f2a_pin_list = [None] * len(port_names["F2A"])
    for port in port_names["A2F"]:
        pin_dir = "input"
        pin_used = False
        if port in csv_pin_data["A2F"]:
            pin_used = True

        clk = ""
        if port in assoc_clk:
            if assoc_clk[port].strip() != "":
                clk = assoc_clk[port].strip()

        index = port_index(port)
        if index != -1:
            pin_data = PinData(name=port, dir=pin_dir, used=pin_used, clk=clk)
            a2f_pin_list[index] = pin_data
        else:
            print("ERROR: No index present in A2F port: '{}'".format(port))

    for port in port_names["F2A"]:
        pin_dir = "output"
        pin_used = False
        if port in csv_pin_data["F2A"]:
            pin_used = True

        clk = ""
        if port in assoc_clk:
            if assoc_clk[port].strip() != "":
                clk = assoc_clk[port].strip()

        index = port_index(port)
        if index != -1:
            pin_data = PinData(name=port, dir=pin_dir, used=pin_used, clk=clk)
            f2a_pin_list[index] = pin_data
        else:
            print("ERROR: No index present in F2A port: '{}'\n".format(port))

    lib_data = ""
    a2f_bus_name = ""
    if len(a2f_pin_list) > 0:
        pos = a2f_pin_list[0].name.find("[")
        if pos != -1:
            a2f_bus_name = a2f_pin_list[0].name[0:pos]
            lib_data += "\n{}bus ( {} ) {{\n".format(add_tab(2), a2f_bus_name)
            lib_data += "\n{}bus_type   : BUS1536_type1 ;".format(add_tab(3))
            lib_data += "\n{}direction  : input ;\n".format(add_tab(3))

    for pin in a2f_pin_list:
        if pin.used:
            curr_str = "\n{}pin ({}) {{".format(add_tab(3), pin.name)
            cap = common_lib_data["input_used"]["cap"]
            max_tran = common_lib_data["input_used"]["max_tran"]
            curr_str += form_pin_header(pin.dir, cap, max_tran)

            if pin.clk != "":
                clks = pin.clk.split(" ")
                for clk in clks:
                    clk_name = clk
                    timing_type = ["setup_rising", "hold_rising"]
                    for val in timing_type:
                        curr_str += form_in_timing_group(clk_name, val, common_lib_data)
            curr_str += "\n{}}} /* end of pin {} */\n".format(add_tab(3), pin.name)
            lib_data += curr_str
        else:
            curr_str = "\n{}pin ({}) {{".format(add_tab(3), pin.name)
            cap = common_lib_data["input_unused"]["cap"]
            max_tran = common_lib_data["input_unused"]["max_tran"]
            curr_str += form_pin_header(pin.dir, cap, max_tran)
            curr_str += "\n{}}} /* end of pin {} */\n".format(add_tab(3), pin.name)
            lib_data += curr_str

    if len(a2f_pin_list) > 0:
        lib_data += "\n{}}} /* end of bus {} */\n".format(add_tab(2), a2f_bus_name)

    f2a_bus_name = ""
    if len(f2a_pin_list) > 0:
        pos = f2a_pin_list[0].name.find("[")
        if pos != -1:
            f2a_bus_name = f2a_pin_list[0].name[0:pos]
            lib_data += "\n{}bus ( {} ) {{\n".format(add_tab(2), f2a_bus_name)
            lib_data += "\n{}bus_type   : BUS1536_type1 ;".format(add_tab(3))
            lib_data += "\n{}direction  : output ;\n".format(add_tab(3))

    for pin in f2a_pin_list:
        if pin.used:
            curr_str = "\n{}pin ({}) {{".format(add_tab(3), pin.name)
            cap = common_lib_data["output_used"]["cap"]
            max_tran = common_lib_data["output_used"]["max_tran"]
            curr_str += form_pin_header(pin.dir, cap, max_tran)

            if pin.clk != "":
                clks = pin.clk.split(" ")
                for clk in clks:
                    clk_name = clk
                    timing_type = "rising_edge"
                    curr_str += form_out_timing_group(clk_name, timing_type, common_lib_data)
                curr_str += form_out_reset_timing_group("RESET_N", "positive_unate", "clear", common_lib_data)
            curr_str += "\n{}}} /* end of pin {} */\n".format(add_tab(3), pin.name)
            lib_data += curr_str
        else:
            curr_str = "\n{}pin ({}) {{".format(add_tab(3), pin.name)
            cap = common_lib_data["output_unused"]["cap"]
            max_tran = common_lib_data["output_unused"]["max_tran"]
            curr_str += form_pin_header(pin.dir, cap, max_tran)
            curr_str += "\n{}}} /* end of pin {} */\n".format(add_tab(3), pin.name)
            lib_data += curr_str
    if len(f2a_pin_list) > 0:
        lib_data += "\n{}}} /* end of bus {} */\n".format(add_tab(2), f2a_bus_name)

    dedicated_pin_tmpl = os.path.join(template_data_path, "dedicated_pin_lib_data.txt")
    dedicated_pin_lib_file = os.path.join(curr_dir, dedicated_pin_tmpl)
    dedicated_pin_data = open(dedicated_pin_lib_file, "r").read()

    inter_str = str1.replace("@dedicated_pin_data@", dedicated_pin_data)

    final_str = inter_str.replace("@user_pin_data@", lib_data)
    with open(lib_file_name, "w") as out_fp:
        out_fp.write(final_str)


# =============================================================================


def port_index(port):
    """
    Returns index in the port name like gfpga_pad_IO_A2F[1248]
    """
    indx_parser = re.compile(r"[a-zA-Z0-9_]*\[(?P<index>[0-9]+)\]$")
    match = indx_parser.fullmatch(port)
    index = -1
    if match is not None:
        index = int(match.group("index"))

    return index


def form_pin_header(direction, cap, max_tran):
    """
    Form pin header section
    """
    curr_str = "\n{}direction : {};\n{}capacitance : {};".format(add_tab(4), direction, add_tab(4), cap)
    curr_str += "\n{}max_transition : {};".format(add_tab(4), max_tran)
    return curr_str


# =============================================================================


def form_out_reset_timing_group(reset_name, timing_sense, timing_type, common_lib_data):
    """
    Form timing group for output pin when related pin is reset
    """
    cell_fall_val = common_lib_data["reset_timing"]["cell_fall_val"]
    fall_tran_val = common_lib_data["reset_timing"]["fall_tran_val"]
    curr_str = '\n{}timing () {{\n{}related_pin : "{}";'.format(add_tab(4), add_tab(5), reset_name)
    curr_str += "\n{}timing_sense : {};".format(add_tab(5), timing_sense)
    curr_str += "\n{}timing_type : {};".format(add_tab(5), timing_type)
    curr_str += "\n{}cell_fall (scalar) {{\n{}values({});\n{}}}".format(
        add_tab(5), add_tab(6), cell_fall_val, add_tab(5)
    )
    curr_str += "\n{}fall_transition (scalar) {{\n{}values({});\n{}}}".format(
        add_tab(5), add_tab(6), fall_tran_val, add_tab(5)
    )
    curr_str += "\n{}}}".format(add_tab(4))
    return curr_str


# =============================================================================


def form_out_timing_group(clk_name, timing_type, common_lib_data):
    """
    Form timing group for output pin in a Pin group in a library file
    """
    cell_rise_val = common_lib_data["output_timing"]["rising_edge_cell_rise_val"]
    cell_fall_val = common_lib_data["output_timing"]["rising_edge_cell_fall_val"]
    rise_tran_val = common_lib_data["output_timing"]["rising_edge_rise_tran_val"]
    fall_tran_val = common_lib_data["output_timing"]["rising_edge_fall_tran_val"]
    curr_str = '\n{}timing () {{\n{}related_pin : "{}";'.format(add_tab(4), add_tab(5), clk_name)
    curr_str += "\n{}timing_type : {};".format(add_tab(5), timing_type)
    curr_str += "\n{}cell_rise (scalar) {{\n{}values({});\n{}}}".format(
        add_tab(5), add_tab(6), cell_rise_val, add_tab(5)
    )
    curr_str += "\n{}rise_transition (scalar) {{\n{}values({});\n{}}}".format(
        add_tab(5), add_tab(6), rise_tran_val, add_tab(5)
    )
    curr_str += "\n{}cell_fall (scalar) {{\n{}values({});\n{}}}".format(
        add_tab(5), add_tab(6), cell_fall_val, add_tab(5)
    )
    curr_str += "\n{}fall_transition (scalar) {{\n{}values({});\n{}}}".format(
        add_tab(5), add_tab(6), fall_tran_val, add_tab(5)
    )
    curr_str += "\n{}}}".format(add_tab(4))
    return curr_str


# =============================================================================


def add_tab(num_tabs):
    """
    Add given number of tabs and return the string
    """
    curr_str = "\t" * num_tabs
    return curr_str


# =============================================================================


def form_in_timing_group(clk_name, timing_type, common_lib_data):
    """
    Form timing group for input pin in a Pin group in a library file
    """
    rise_constraint_val = "0.0"
    fall_constraint_val = "0.0"
    if timing_type == "setup_rising":
        rise_constraint_val = common_lib_data["input_timing"]["setup_rising_rise_constraint_val"]
        fall_constraint_val = common_lib_data["input_timing"]["setup_rising_fall_constraint_val"]
    else:
        rise_constraint_val = common_lib_data["input_timing"]["hold_rising_rise_constraint_val"]
        fall_constraint_val = common_lib_data["input_timing"]["hold_rising_fall_constraint_val"]

    curr_str = '\n{}timing () {{\n{}related_pin : "{}";'.format(add_tab(4), add_tab(5), clk_name)
    curr_str += "\n{}timing_type : {};".format(add_tab(5), timing_type)
    curr_str += "\n{}rise_constraint (scalar) {{\n{}values({});\n{}}}".format(
        add_tab(5), add_tab(6), rise_constraint_val, add_tab(5)
    )
    curr_str += "\n{}fall_constraint (scalar) {{\n{}values({});\n{}}}".format(
        add_tab(5), add_tab(6), fall_constraint_val, add_tab(5)
    )
    curr_str += "\n{}}}".format(add_tab(4))
    return curr_str


# =============================================================================


def parse_xml(xml_file):
    """
    Parses given xml file and collects the desired data
    """
    parser = ET.XMLParser(resolve_entities=False, strip_cdata=False)
    xml_tree = ET.parse(xml_file, parser)
    xml_root = xml_tree.getroot()

    port_names = defaultdict(set)
    # Get the "IO" section
    xml_io = xml_root.find("IO")
    if xml_io is None:
        print("ERROR: No mandatory 'IO' section defined in 'DEVICE' section")
        sys.exit(1)

    xml_top_io = xml_io.find("TOP_IO")
    if xml_top_io is not None:
        port_names = parse_xml_io(xml_top_io, port_names)

    xml_bottom_io = xml_io.find("BOTTOM_IO")
    if xml_bottom_io is not None:
        port_names = parse_xml_io(xml_bottom_io, port_names)

    xml_left_io = xml_io.find("LEFT_IO")
    if xml_left_io is not None:
        port_names = parse_xml_io(xml_left_io, port_names)

    xml_right_io = xml_io.find("RIGHT_IO")
    if xml_right_io is not None:
        port_names = parse_xml_io(xml_right_io, port_names)

    return port_names


# =============================================================================


def parse_xml_io(xml_io, port_names):
    """
    Parses xml and get data for mapped_name key
    """
    assert xml_io is not None
    for xml_cell in xml_io.findall("CELL"):
        mapped_name = xml_cell.get("mapped_name")
        # define properties for scalar pins
        scalar_mapped_pins = vec_to_scalar(mapped_name)
        if mapped_name.find("F2A") != -1:
            port_names["F2A"].update(scalar_mapped_pins)
        elif mapped_name.find("A2F") != -1:
            port_names["A2F"].update(scalar_mapped_pins)
    return port_names


# =============================================================================


def vec_to_scalar(port_name):
    """
    Converts given bus port into a list of its scalar port equivalents
    """
    scalar_ports = []
    if port_name is not None and ":" in port_name:
        open_brace = port_name.find("[")
        close_brace = port_name.find("]")
        if open_brace == -1 or close_brace == -1:
            print(
                'Invalid portname "{}" specified. Bus ports should contain [ ] to specify range'.format(port_name),
                file=sys.stderr,
            )
            sys.exit(1)
        bus = port_name[open_brace + 1 : close_brace]
        lsb = int(bus[: bus.find(":")])
        msb = int(bus[bus.find(":") + 1 :])
        if lsb > msb:
            for i in range(lsb, msb - 1, -1):
                curr_port_name = port_name[:open_brace] + "[" + str(i) + "]"
                scalar_ports.append(curr_port_name)
        else:
            for i in range(lsb, msb + 1):
                curr_port_name = port_name[:open_brace] + "[" + str(i) + "]"
                scalar_ports.append(curr_port_name)
    else:
        scalar_ports.append(port_name)

    return scalar_ports


# =============================================================================

if __name__ == "__main__":
    main()
