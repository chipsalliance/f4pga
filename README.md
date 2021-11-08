# Yosys SymbiFlow Plugins

This repository contains plugins for
[Yosys](https://github.com/YosysHQ/yosys.git) developed as
[part of the SymbiFlow project](https://symbiflow.github.io).

## List of plugins
1. [Design introspection](#design-introspection-plugin)
2. [FASM](#fasm-plugin)
3. [Integrate inverters](#integrate-inverters-plugin)
4. [Parameters](#parameters-plugin)
5. [QuickLogic IOBs](#quicklogic-iob-plugin)
6. [QuickLogic QLF FPGAs](#quicklogic-qlf-plugin)
7. [SDC](#sdc-plugin)
8. [XDC](#xdc-plugin)
9. [UHDM](#uhdm-plugin)

## Summary

### Design introspection plugin

Adds several commands that allow for collecting information about cells, nets, pins and ports in the design or a selection of objects.
Additionally provides functions to convert selection on TCL lists.

Following commands are added with the plugin:
* get_cells
* get_nets
* get_pins
* get_ports
* get_count
* selection_to_tcl_list

### FASM plugin

Writes out the design's [fasm features](https://symbiflow.readthedocs.io/en/latest/fasm/docs/specification.html) based on the parameter annotations on a design cell.

The plugin adds the following command:
* write_fasm

### Integrate inverters plugin

Implements a pass that integrates inverters into cells that have ports with the 'invertible_pin' attribute set.

The plugin adds the following command:
* integrateinv

### Parameters plugin

Reads the specified parameter on a selected object.

The plugin adds the following command:
* getparam

### QuickLogic IOB plugin

[QuickLogic IOB plugin](./ql-iob-plugin/) annotates IO buffer cells with information from IO placement constraints. Used during synthesis for QuickLogic EOS-S3 architecture.

The plugin adds the following command:
* quicklogic_iob

### QuickLogic QLF FPGAs plugin

[QuickLogic QLF plugin](./ql-qlf-plugin) extends Yosys with synthesis support for `qlf_k4n8` and `qlf_k6n10` architectures.

The plugin adds the following command:
* synth_quicklogic
* ql_dsp

Detailed help on the supported command(s) can be obtained by running `help <command_name>` in Yosys.

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

### UHDM plugin

Reads UHDM files and processes it into yosys AST.

The plugin adds the following commands:
* read_uhdm
* read_verilog_with_uhdm

Detailed help on the supported command(s) can be obtained by running `help <command_name>` in Yosys.
