# FOSS Flows For FPGA (F4PGA) project

<p align="center">
  <a title="Website" href="https://f4pga.org"><img src="https://img.shields.io/website?longCache=true&style=flat-square&label=f4pga.org&up_color=10cfc9&url=https%3A%2F%2Ff4pga.org%2Findex.html&labelColor=fff"></a><!--
  -->
  <a title="Community" href="https://f4pga.readthedocs.io/en/latest/community.html#communication"><img src="https://img.shields.io/badge/Chat-IRC%20%7C%20Slack-white?longCache=true&style=flat-square&logo=Slack&logoColor=fff"></a><!--
  -->
  <a title="'Automerge' workflow status" href="https://github.com/chipsalliance/f4pga/actions/workflows/Doc.yml"><img alt="'Automerge' workflow status" src="https://img.shields.io/github/workflow/status/chipsalliance/f4pga/Automerge/main?longCache=true&style=flat-square&label=Tests&logo=Github%20Actions&logoColor=fff"></a><!--
  -->
</p>

This is the top-level repository for the [F4PGA](https://f4pga.org/) project, which is a Workgroup under the [CHIPS Alliance](https://chipsalliance.org).
The elements of the project include (but are not limited to):

* The F4PGA open source FPGA toolchains for programming FPGAs (formerly known as [SymbiFlow](https://github.com/SymbiFlow)).
  This includes:

  * [![Documentation](https://img.shields.io/website?longCache=true&style=flat-square&label=Documentation&up_color=1226aa&up_message=%E2%9E%9A&url=https%3A%2F%2Ff4pga.readthedocs.io%2Fen%2Flatest%2Findex.html&labelColor=fff)](https://f4pga.readthedocs.io)
  * F4PGA Architecture Definitions [![Arch-Defs (for Developers)](https://img.shields.io/website?longCache=true&style=flat-square&label=For%20Developers&up_color=231f20&up_message=%E2%9E%9A&url=https%3A%2F%2Ff4pga.readthedocs.io%2Fprojects%2Farch-defs%2Fen%2Flatest%2Findex.html&labelColor=fff)](https://f4pga.readthedocs.io/projects/arch-defs)
  * F4PGA Examples [![Examples (for Users)](https://img.shields.io/website?longCache=true&style=flat-square&label=For%20Users&up_color=231f20&up_message=%E2%9E%9A&url=https%3A%2F%2Ff4pga-examples.readthedocs.io%2Fen%2Flatest%2Findex.html&labelColor=fff)](https://f4pga-examples.readthedocs.io)
  * [F4PGA Yosys plugins](https://github.com/chipsalliance/yosys-f4pga-plugins)

* The FPGA interchange format (an interchange format defined by CHIPS Alliance to enable interoperability between
  different FPGA tools) adopted by the F4PGA toolchain:

  * [FPGA Interchange schema](https://github.com/chipsalliance/fpga-interchange-schema)
  * [FPGA Interchange Python utilities](https://github.com/chipsalliance/python-fpga-interchange)
  * [FPGA Interchange Test suite](https://github.com/SymbiFlow/fpga-interchange-tests)

* The [FPGA tool performance framework](https://github.com/chipsalliance/fpga-tool-perf) framework for benchmarking
  designs against various FPGA tools, and vice versa, over time.

* FPGA Database visualisation tools for visual exploration of FPGA bitstream and databases:

  * [F4PGA bitstream viewer](https://github.com/SymbiFlow/f4pga-bitstream-viewer)
  * [F4PGA database visualizer](https://github.com/chipsalliance/f4pga-database-visualizer)

* Other utilities (FPGA assembly format, documentation and other):

  * [F4PGA Assembly (FASM)](https://github.com/chipsalliance/fasm)
  * [Xilinx bitstream generation library](https://github.com/SymbiFlow/f4pga-xc-fasm)
  * [Verilog-to-routing XML utilities](https://github.com/SymbiFlow/vtr-xml-utils)
  * [SDF format utilities](https://github.com/chipsalliance/python-sdf-timing)
  * [F4PGA tools data manager](https://github.com/SymbiFlow/symbiflow-tools-data-manager)
  * [F4PGA Sphinx Theme](https://github.com/SymbiFlow/sphinx_symbiflow_theme)
  * [F4PGA Sphinx HDL diagrams](https://github.com/SymbiFlow/sphinxcontrib-hdl-diagrams)
  * [F4PGA Sphinx Verilog domain](https://github.com/SymbiFlow/sphinx-verilog-domain)

## F4PGA Workgroup

The F4PGA Workgroup consists of members from different backgrounds, including FPGA vendors
([Xilinx](https://www.xilinx.com/) and [QuickLogic](https://www.quicklogic.com/)),
industrial users
([Google](https://www.google.com/), [Antmicro](https://antmicro.com/))
and academia
([University of Toronto](https://www.utoronto.ca/)),
who collaborate to build a more open source and software-driven FPGA ecosystem (IP, tools and workflows) to drive the
adoption of FPGAs in existing and new use cases, and eliminate barriers of entry.
