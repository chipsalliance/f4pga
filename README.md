# Yosys SymbiFlow Plugins

This repository contains plugins for
[Yosys](https://github.com/YosysHQ/yosys.git) developed as
[part of the SymbiFlow project](https://symbiflow.github.io).

## List of plugins
1. [Design introspection](#design-introspection-plugin)
2. [FASM](#fasm-plugin)
3. [Get count](#get-count-plugin)
4. [Integrate inverters](#integrate-inverters-plugin)
5. [Parameters](#parameters-plugin) 
6. [QL IOBs](#quicklogic-iob-plugin)
7. [SDC](#sdc-plugin)
8. [Selection](#selection-plugin)
9. [XDC](#xdc-plugin)

## Summary

### Design introspection plugin

Adds several commands that allow for collecting information about cells, nets, pins and ports in the design.

Following commands are added with the plugin:
* get_cells
* get_nets
* get_pins
* get_ports

### FASM plugin

Writes out the design's [fasm features](https://symbiflow.readthedocs.io/en/latest/fasm/docs/specification.html) based on the parameter annotations on a design cell.

The plugin adds the following command:
* write_fasm

### Get count plugin

Returns the count of selected objects to the TCL interpreter.
The objects can be of various types, such as modules, cells or wires.

The plugin adds the following command:
* get_count

### Integrate inverters plugin

Implements a pass that integrates inverters into cells that have ports with the 'invertible_pin' attribute set.

The plugin adds the following command:
* integrateinv

### Parameters plugin

Reads the specified parameter on a selected object.

The plugin adds the following command:
* getparam

### QuickLogic IOB plugin

[QL IOB plugin](./ql-iob-plugin/) annotates IO buffer cells with information from IO placement constraints.

The plugin adds the following command:
* quicklogic_iob

### SDC plugin

Reads Standard Delay Format (SDC) constraints, propagates these constraints across the design and writes out the complete SDC information.

The plugin adds the following commands:
* read_sdc
* write_sdc
* create_clock
* get_clocks
* propagate_clocks
* set_false_path
* set_max_delay
* set_clock_groups

### Selection plugin

Extracts the current selection to TCL list

The plugin adds the following command:
* selection_to_tcl_list

### XDC plugin

Reads Xilinx Design Constraints (XDC) files and annotates the specified cells parameters with properties such as:
* INTERNAL_VREF
* IOSTANDARD
* SLEW
* DRIVE
* IN_TERM
* LOC
* PACKAGE_PIN 

The plugin adds the following commands:
* read_xdc
* get_iobanks
* set_property
* get_bank_tiles
