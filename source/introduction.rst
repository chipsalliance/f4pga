Introduction
============

SymbiFlow is a Open Source Verilog-to-Bitstream FPGA synthesis flow,
currently targeting Xilinx 7-Series, Lattice iCE40 and Lattice ECP5 FPGAs.
Think of it as the GCC of FPGAs.

The project aim is to design tools that are highly extendable and multiplatform.

EDA Tooling Ecosystem
---------------------

For both ASIC- and FPGA-oriented EDA tooling, there are three major areas that
the workflow needs to cover: hardware description, frontend and backend.

Hardware description languages are generally open, with both established HDLs
such as Verilog and VHDL and emerging software-inspired paradigms like
`Chisel <https://chisel.eecs.berkeley.edu/>`_,
`SpinalHDL <https://spinalhdl.github.io/SpinalDoc-RTD/>`_ or
`Migen <https://m-labs.hk/gateware/migen/>`_.
The major problem lies however in the front- and backend, where previously
there was no established standard, vendor-neutral tooling that would cover
all the necessary components for an end-to-end flow.

This pertains both to ASIC and FPGA workflows, although SymbiFlow focuses
on the latter (some parts of SymbiFlow will also be useful in the former).

.. figure:: images/EDA.svg

Project structure
-----------------

To achieve SymbiFlow's goal of a complete FOSS FPGA toolchain,
a number of tools and projects are necessary to provide all the needed
components of an end-to-end flow. Thus, SymbiFlow serves as an umbrella
project for several activities, the central of which pertains to the
creation of so-called FPGA "architecture definitions",
i.e. documentation of how specific FPGAs work internally.
More information can be found in the :doc:`Symbiflow Architecture Definitions
<../symbiflow-arch-defs/docs/source/index>` project.

Those definitions and serve as input to backend tools like
`nextpnr <https://github.com/YosysHQ/nextpnr>`_ and
`Verilog to Routing <https://verilogtorouting.org/>`_, and frontend tools
like `Yosys <http://www.clifford.at/yosys/>`_. They are created within separate
collaborating projects targeting different FPGAs - :doc:`Project X-Ray
<../prjxray/docs/index>` for Xilinx 7-Series, `Project IceStorm
<http://www.clifford.at/icestorm/>`_ for Lattice iCE40 and :doc:`Project Trellis
<../prjtrellis/docs/index>` for Lattice ECP5 FPGAs.

.. figure:: images/parts.svg

Current status of bitstream documentation
-----------------------------------------

.. table::
    :align: center
    :widths: 40 20 20 20

    +-----------------+----------+----------+---------+
    | Projects        | IceStorm | X-Ray    | Trellis |
    +=================+==========+==========+=========+
    | **Basic Tiles**                                 |
    +-----------------+----------+----------+---------+
    | Logic           | Yes      | Yes      | Yes     |
    +-----------------+----------+----------+---------+
    | Block RAM       | Yes      | Partial  | N/A     |
    +-----------------+----------+----------+---------+
    | **Advanced Tiles**                              |
    +-----------------+----------+----------+---------+
    | DSP             | Yes      | No       | Yes     |
    +-----------------+----------+----------+---------+
    | Hard Blocks     | Yes      | No       | Yes     |
    +-----------------+----------+----------+---------+
    | Clock Tiles     | Yes      | Partial  | Yes     |
    +-----------------+----------+----------+---------+
    | IO Tiles        | Yes      | Partial  | Yes     |
    +-----------------+----------+----------+---------+
    | **Routing**                                     |
    +-----------------+----------+----------+---------+
    | Logic           | Yes      | Yes      | Yes     |
    +-----------------+----------+----------+---------+
    | Clock           | Yes      | Partial  | Yes     |
    +-----------------+----------+----------+---------+
