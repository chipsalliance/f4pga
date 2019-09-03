Versatile Place and Route
=========================

Versatile Place and Route (VPR) is an open-source CAD tool that
implements different placing and routing algorithms for FPGAs. It can be used
to prepare a description of a complete chip configuration
from a given logic design.

As its input, the VPR takes the netlist specified in the `BLIF
file format <https://docs.verilogtorouting.org/en/latest/_downloads/773c1e1024574545e6f692e46935cee0/blif.pdf>`_
and `architecture definition <https://docs.verilogtorouting.org/en/latest/tutorials/arch/#arch-tutorial>`_
in the XML file. The whole process of generating configuration is described in
`FPGA Design Flow <./design-flow.html>`_. One of the most important goals of
the SymbiFlow Toolchain is to provide accurate `architecture definitions
<../symbiflow-arch-defs/docs/source/index.html>`__ that are needed in the
Place and Route process.

Summary
-------

The Place and Route process in VPR consists of a few steps:

- Packing (combining primitives into complex logic blocks)
- Placing (placement of complex block inside FPGA)
- Routing (planning interconnections between blocks)
- Analysis

Each of these steps provides additional configuration options that can be used
for customizing the whole process. Detailed description is avaliable on the
project website in the `VPR section <https://vtr.readthedocs.io/en/latest/vpr/>`_ of the VTR documentation.

Packing
-------

The packing algorithm tries to combine primitive logic blocks into groups,
called Complex Logic Blocks. The results from the packing process are written
into a ``.net`` file. It contains a description of complex blocks with their
inputs, outputs, used clocks and relations to other signals.
It can be useful in analyzing how VPR packs primitives together.

A detailed description of the ``.net`` file format can be found in the `VPR documentation
<https://vtr.readthedocs.io/en/latest/vpr/file_formats/#packed-netlist-format-net>`_.

Placing
-------

This step assigns a location to the Complex Logic Block onto the FPGA.
The output from this step is written in the ``.place`` file, which contains
the physical location of the blocks from the ``.net`` file.

The File has the following format:

.. code-block:: bash

    block_name    x        y   subblock_number

where ``x`` and ``y`` are positions in VPR grid and ``block_name`` comes from
the ``.net`` file.

Example placing file:

.. code-block::

    Netlist_File: top.net Netlist_ID: SHA256:ce5217d251e04301759ee5a8f55f67c642de435b6c573148b67c19c5e054c1f9
    Array size: 149 x 158 logic blocks

    #block name	x	y	subblk	block number
    #----------	--	--	------	------------
    $auto$alumacc.cc:474:replace_alu$24.slice[1].carry4_full	53	32	0	#0
    $auto$alumacc.cc:474:replace_alu$24.slice[2].carry4_full	53	31	0	#1
    $auto$alumacc.cc:474:replace_alu$24.slice[3].carry4_full	53	30	0	#2
    $auto$alumacc.cc:474:replace_alu$24.slice[4].carry4_full	53	29	0	#3
    $auto$alumacc.cc:474:replace_alu$24.slice[5].carry4_full	53	28	0	#4
    $auto$alumacc.cc:474:replace_alu$24.slice[6].carry4_part	53	27	0	#5
    $auto$alumacc.cc:474:replace_alu$24.slice[0].carry4_1st_full	53	33	0	#6
    out:LD7		9	5	0	#7
    clk		42	26	0	#8
    $false		35	26	0	#9

Detailed description of the ``.place`` file format can be found in the `VPR documentation
<https://vtr.readthedocs.io/en/latest/vpr/file_formats/#placement-file-format-place>`_.

Routing
-------

This step connects the placed Complex Logic Blocks together,
according to the netlist specifications and the routing resources
of the FPGA chip. The description of the routing resources is
provided in the `architecture definition file
<https://docs.verilogtorouting.org/en/latest/arch/reference/#arch-reference>`__.
Starting from the architecture definition, VPR generates the Resource
Routing Graph. SymbiFlow provides a complete graph file for each architecture.
This `precompiled` file can be directly injected into the routing process.
The output from this step is written into ``.route`` file.

The file describes each connection from input to its output through
different routing resources of FPGA. Each net starts with a ``SOURCE`` node and
ends in a ``SINK`` node. The node name describes the kind of routing resource.
The pair of numbers in round brackets provides information on the (x, y)
resource location on the VPR grid. The additional field provides information
for a specific kind of node.

Example routing file may look similar:

.. code-block::

    Placement_File: top.place Placement_ID: SHA256:88d45f0bf7999e3f9331cdfd3497d0028be58ffa324a019254c2ae7b4f5bfa7a
    Array size: 149 x 158 logic blocks.

    Routing:

    Net 0 (counter[4])

    Node:	203972	SOURCE (53,32)  Class: 40  Switch: 0
    Node:	204095	  OPIN (53,32)  Pin: 40   BLK-TL-SLICEL.CQ[0] Switch: 189
    Node:	1027363	 CHANY (52,32)  Track: 165  Switch: 7
    Node:	601704	 CHANY (52,32)  Track: 240  Switch: 161
    Node:	955959	 CHANY (52,32) to (52,33)  Track: 90  Switch: 130
    Node:	955968	 CHANY (52,32)  Track: 238  Switch: 128
    Node:	955976	 CHANY (52,32)  Track: 230  Switch: 131
    Node:	601648	 CHANY (52,32)  Track: 268  Switch: 7
    Node:	1027319	 CHANY (52,32)  Track: 191  Switch: 183
    Node:	203982	  IPIN (53,32)  Pin: 1   BLK-TL-SLICEL.A2[0] Switch: 0
    Node:	203933	  SINK (53,32)  Class: 1  Switch: -1

   Net 1 ($auto$alumacc.cc:474:replace_alu$24.O[6])
   ...

A detailed description of the ``.route`` file format can be found in the `VPR documentation
<https://vtr.readthedocs.io/en/latest/vpr/file_formats/#routing-file-format-route>`_.

FASM file
---------

SymbiFlow makes use of an additional tool provided by VPR, called
`genfasm <https://docs.verilogtorouting.org/en/latest/utils/fasm/>`_.
In fact, genfasm translates the routed design into a FASM format file.
This file provides the description of the implemented design in terms of
features that need to be enabled or disabled in the FPGA chip.

These changes are made with respect to the default FPGA configuration.
Due to that, empty FASM file sets the FPGA to the default configuration.

FASM file contains lines in the format:

.. code-block::

   YYYY.XXXXX  [A:B] = C

which corresponds respectively to the feature ID, feature address
and the feature value. The feature ID unambiguously describes the location of
the resource that needs to be modified. Within this resource, may exists several
bits that determine its behaviour. The feature address specifies the set of bits
in the resource that will be changed to the chosen feature value.

Example of a FASM line:

.. code-block::

   CLBLM_R_X41Y31.SLICEL_X1.ALUT.INIT[63:32]=32'b11110000111100001111000011110000

will initialize the bits ``[63:32]`` of ``ALUT.INIT`` feature, located in the
``SLICEL_X1`` of the ``CLBLM_R_X41Y31`` tile with the
``32'b11110000111100001111000011110000`` value.

It is worth to mention that only the feature ID is necessary and setting feature
value to ``0`` means that feature has a default setting not that it is disabled.

A detailed description of FASM file format used in SymbiFlow could be found
in the `FASM specification <../used-standards/fasm-specification.html>`_.
