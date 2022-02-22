# FOSS Flow For FPGA (F4PGA) project

This is the top-level repository for the F4PGA project, which is a Workgroup under the [CHIPS Alliance](https://chipsalliance.org).
The elements of the project include (but are not limited to):

* The F4PGA open source FPGA toolchains for programming FPGAs - formerly known as [SymbiFlow](https://github.com/SymbiFlow). This includes:

  * [F4PGA documentation](https://github.com/chipsalliance/f4pga-docs) (knowledge base)
  * [F4PGA Architecture Definitions](https://github.com/SymbiFlow/f4pga-arch-defs)
  * [F4PGA examples](https://github.com/chipsalliance/f4pga-examples)
  * [F4PGA Yosys plugins](https://github.com/f4pga/yosys-f4pga-plugins)

* The FPGA interchange format - an interchange format defined by CHIPS Alliance to enable interoperability between different FPGA tools - adopted by the F4PGA toolchain:

  * [FPGA Interchange schema](https://github.com/chipsalliance/fpga-interchange-schema)
  * [FPGA Interchange Python utilities](https://github.com/chipsalliance/python-fpga-interchange)
  * [FPGA Interchange Test suite](https://github.com/SymbiFlow/fpga-interchange-tests)

* The [FPGA tool performance framework](https://github.com/chipsalliance/fpga-tool-perf) - a framework for benchmarking designs against various FPGA tools, and vice versa, over time

* FPGA Database visualisation tools - tools for visual exploration of FPGA bitstream and databases

  * [F4PGA bitstream viewer](https://github.com/SymbiFlow/f4pga-bitstream-viewer)
  * [F4PGA database visualizer](https://github.com/chipsalliance/f4pga-database-visualizer)

* Other utilities - FPGA assembly format, documentation and other utilities

  * [F4PGA Assembly (FASM)](https://github.com/chipsalliance/fasm)
  * [Xilinx bitstream generation library](https://github.com/SymbiFlow/f4pga-xc-fasm)
  * [Verilog-to-routing XML utilities](https://github.com/SymbiFlow/vtr-xml-utils)
  * [SDF format utilities](https://github.com/chipsalliance/python-sdf-timing)
  * [F4PGA tools data manager](https://github.com/SymbiFlow/symbiflow-tools-data-manager)
  * [F4PGA Sphinx Theme](https://github.com/SymbiFlow/sphinx_symbiflow_theme)
  * [F4PGA Sphinx HDL diagrams](https://github.com/SymbiFlow/sphinxcontrib-hdl-diagrams)
  * [F4PGA Sphinx Verilog domain](https://github.com/SymbiFlow/sphinx-verilog-domain)

The F4PGA Workgroup consists of members from different backgrounds, including FPGA vendors (Xilinx and QuickLogic), industrial users (Google, Antmicro) and academia (University of Toronto), who collaborate to build a more open source and software-driven FPGA ecosystem - IP, tools and workflows - to drive the adoption of FPGAs in existing and new use cases, and eliminate barriers of entry.
