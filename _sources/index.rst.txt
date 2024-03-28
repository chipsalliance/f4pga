FOSS Flows For FPGA
###################

`F4PGA ➚ <https://f4pga.org/>`__, which is a Workgroup under the `CHIPS Alliance ➚ <https://chipsalliance.org>`__, is an
Open Source solution for Hardware Description Language (HDL) to Bitstream FPGA synthesis, currently targeting
Xilinx's 7-Series, QuickLogic's EOS-S3, and Lattice' iCE40 and ECP5 devices.
Think of it as the GCC of FPGAs.
The project aims to design tools that are highly extendable and multiplatform.

.. image:: _static/images/hero.svg
  :align: center

The elements of the project include (but are not limited to):

* The F4PGA open source FPGA toolchains for programming FPGAs (formerly known as :gh:`SymbiFlow ➚ <https://github.com/SymbiFlow>`):

  * :gh:`F4PGA Python CLI ➚ <chipsalliance/f4pga/tree/main/f4pga>`
  * :gh:`F4PGA Architecture Definitions ➚ <SymbiFlow/f4pga-arch-defs>`
  * :gh:`F4PGA Examples ➚ <chipsalliance/f4pga-examples>`
  * :gh:`F4PGA Yosys plugins ➚ <chipsalliance/yosys-f4pga-plugins>`

* The FPGA interchange format (an interchange format defined by CHIPS Alliance to enable interoperability between
  different FPGA tools) adopted by the F4PGA toolchain:

  * :gh:`FPGA Interchange schema ➚ <chipsalliance/fpga-interchange-schema>`
  * :gh:`FPGA Interchange Python utilities ➚ <chipsalliance/python-fpga-interchange>`
  * :gh:`FPGA Interchange Test suite ➚ <SymbiFlow/fpga-interchange-tests>`

* The :gh:`FPGA tool performance framework ➚ <chipsalliance/fpga-tool-perf>` framework for benchmarking
  designs against various FPGA tools, and vice versa, over time.

* FPGA visualisation tools for visual exploration of FPGA bitstream and databases:

  * :gh:`F4PGA bitstream viewer ➚ <SymbiFlow/f4pga-bitstream-viewer>`
  * :gh:`F4PGA database visualizer ➚ <chipsalliance/f4pga-database-visualizer>`

* Other utilities (FPGA assembly format, documentation and other):

  * :gh:`F4PGA Assembly (FASM) ➚ <chipsalliance/fasm>`
  * :gh:`Xilinx bitstream generation library ➚ <SymbiFlow/f4pga-xc-fasm>`
  * :gh:`Verilog-to-routing XML utilities ➚ <SymbiFlow/vtr-xml-utils>`
  * :gh:`SDF format utilities ➚ <chipsalliance/python-sdf-timing>`
  * :gh:`F4PGA tools data manager ➚ <SymbiFlow/symbiflow-tools-data-manager>`
  * :gh:`F4PGA Sphinx Theme ➚ <SymbiFlow/sphinx_symbiflow_theme>`
  * :gh:`F4PGA Sphinx HDL diagrams ➚ <SymbiFlow/sphinxcontrib-hdl-diagrams>`
  * :gh:`F4PGA Sphinx Verilog domain ➚ <SymbiFlow/sphinx-verilog-domain>`


Table of Contents
=================

.. toctree::
  :caption: About F4PGA

  getting-started
  how
  status
  community


.. toctree::
  :caption: Python utils
  :maxdepth: 2

  f4pga/index
  f4pga/Usage
  f4pga/modules/index
  f4pga/DevNotes
  f4pga/Deprecated


.. toctree::
  :caption: Development

  development/changes
  development/building-docs
  development/venv


.. toctree::
  :caption: Design Flows

  flows/index
  flows/synthesis
  flows/pnr
  flows/bitstream
  flows/f4pga


.. toctree::
  :caption: Specifications

  FPGA Assembly (FASM) ➚ <https://fasm.readthedocs.io/en/latest/>
  FPGA Interchange schema ➚ <https://chipsalliance/fpga-interchange-schema>


.. toctree::
  :caption: Appendix

  glossary
  references
