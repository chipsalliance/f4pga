In F4PGA
########

Synthesis
*********

In the F4PGA toolchain synthesis is made with the use of Yosys, that is able to perform all the mentioned steps and
convert HDL to netlist description.
The result of these steps is written to a file in ``.eblif`` format.

.. _Flows:F4PGA:Yosys:

Yosys
=====

Yosys is a Free and Open Source Verilog HDL synthesis tool.
It was designed to be highly extensible and multiplatform.
In F4PGA toolchain, it is responsible for the whole synthesis process described in `FPGA Design Flow <./design-flow.html>`_

It is not necessary to call Yosys directly using F4PGA.
Nevertheless, the following description, should provide sufficient introduction to Yosys usage inside the project.
It is also a good starting point for a deeper understanding of the whole toolchain.

Short description
-----------------

Yosys consists of several subsystems. Most distinguishable are the first and last ones used in the synthesis process,
called *frontend* and *backend* respectively.
Intermediate subsystems are called *passes*.

The *frontend* is responsible for changing the Verilog input file into an internal Yosys, representation which is common
for all *passes* used by the program.
The *passes* are responsible for a variety of optimizations (``opt_``) and simplifications (``proc_``).

Two *passes*, that are worth to mention separately are ``ABC`` and ``techmap``.
The first one optimizes logic functions from the design and assigns obtained results into Look Up Tables (LUTs) of
chosen width.
The second mentioned *pass* - ``techmap`` is responsible for mapping the synthesized design from Yosys internal blocks
to the primitives used by the implementation tool.
Recommended synthesis flows for different FPGAs are combined into macros i.e. ``synth_ice40`` (for Lattice iCE40 FPGA)
or ``synth_xilinx`` (for Xilinx 7-series FPGAs).

The *backend* on the other hand, is responsible for converting internal Yosys representation into one of the
standardized formats.
F4PGA uses ``.eblif`` as its output file format.

Usage in Toolchain
------------------

All operations performed by Yosys are written  in ``.tcl`` script. Commands used
in the scripts are responsible for preparing output file to match with the
expectations of other toolchain tools.
There is no need to change it even for big designs.
An example configuration script can be found below:

.. code-block:: tcl

    yosys -import

    synth_ice40 -nocarry

    opt_expr -undriven
    opt_clean

    setundef -zero -params
    write_blif -attr -cname -param $::env(OUT_EBLIF)
    write_verilog $::env(OUT_SYNTH_V)

It can be seen that this script performs a platform-specific process of synthesis, some optimization steps (``opt_``
commands), and writes the final file in ``.eblif`` and Verilog formats.
Yosys synthesis configuration scripts are platform-specific and can by found in ``<platform-dir>/yosys/synth.tcl`` in
the :gh:`F4PGA Architecture Definitions <SymbiFlow/f4pga-arch-defs>` repository.

To understand performed operations, view the log file.
It is usually generated in the project build directory. It should be named ``top.eblif.log``.

Output analysis
---------------

Input file:

.. code-block:: verilog

    module top (
    	input  clk,
    	output LD7,
    );
    	localparam BITS = 1;
    	localparam LOG2DELAY = 25;

    	reg [BITS+LOG2DELAY-1:0] counter = 0;
    	always @(posedge clk) begin
    		counter <= counter + 1;
    	end

    	assign {LD7} = counter >> LOG2DELAY;
    endmodule


after synthesis is described only with use of primitives appropriate for
chosen platform:

.. code-block:: verilog

    module top(clk, LD7);
      wire [25:0] _000_;
      wire _001_;

    ...

      FDRE_ZINI #(
        .IS_C_INVERTED(1'h0),
        .ZINI(1'h1)
      ) _073_ (
        .C(clk),
        .CE(_012_),
        .D(_000_[0]),
        .Q(counter[0]),
        .R(_013_)
      );

    ...

      SR_GND _150_ (
        .GND(_062_)
      );
      assign _003_[25:0] = _000_;
      assign counter[25] = LD7;
    endmodule

The same structure is described by the ``.eblif`` file.


Technology mapping in F4PGA toolchain
-------------------------------------

.. _Xilinx 7 Series FPGAs Clocking Resources User Guide: https://www.xilinx.com/support/documentation/user_guides/ug472_7Series_Clocking.pdf#page=38
.. _VTR FPGA Architecture Description: https://docs.verilogtorouting.org/en/latest/arch/
.. _techmap section in the Yosys Manual: https://yosyshq.net/yosys/files/yosys_manual.pdf#page=153

It is important to understand the connection between the synthesis and
implementation tools used in the F4PGA toolchain. As mentioned before,
synthesis tools like Yosys take the design description from the source files
and convert them into a netlist that consists of the primitives used by
the implementation tool. Usually, to support multiple implementation tools,
an additional intermediate representation of FPGA primitives is provided.
The process of translating the primitives from the synthesis
tool’s internal representation to the specific primitives used in the
implementation tools is called technology mapping (or techmapping).

Technology mapping for VPR
--------------------------

As mentioned before, VPR is one of the implementation tools (often referred to
as Place & Route or P&R tools) used in F4PGA. By default, the F4PGA
toolchain uses it during bitstream generation for, i.e., Xilinx 7-Series
devices. Since the architecture models for this FPGA family were created from
scratch, appropriate techmaps were needed to instruct Yosys on translating
the primitives to the versions compatible with VPR.

The clock buffers used in the 7-Series devices are a good example for explaining
the techmapping process. Generally, as stated in the
`Xilinx 7 Series FPGAs Clocking Resources User Guide`_, a designer has various
buffer types that they can use in designs:

- ``BUFGCTRL``
- ``BUFG``
- ``BUFGCE``
- ``BUFGCE_1``
- ``BUFGMUX``
- ``BUFGMUX_1``
- ``BUFGMUX_CTRL``

Nevertheless, the actual chips consist only of the ``BUFGCTRL`` primitives,
which are the most universal and can function as other clock buffer
primitives from the Xilinx manual. Because of that, only one architecture model
is required for VPR. The rest of the primitives are mapped to this general
buffer during the techmapping process. The model of ``BUFGCTRL`` primitive used
by VPR is called ``BUFGCTR_VPR`` (More information about the architecture
modeling in VPR can be found in the `VTR FPGA Architecture Description`_).

Support for particular primitive in VTR consist of two files:

- Model XML (``xxx.model.xml``) - Contains general information about
  the module's input and output ports and their relations.

- Physical Block XML (``xxx.pb_type.xml``) - Describes the actual layout of the
  primitive, with information about the timings, internal connections, etc.

Below you can see the pb_type XML for ``BUFGCTRL_VPR`` primitive:

.. code-block:: xml

   <!-- Model of BUFG group in BUFG_CLK_TOP/BOT -->
   <pb_type name="BLK-TL-BUFGCTRL" xmlns:xi="https://www.w3.org/2001/XInclude">
     <output name="O" num_pins="1"/>
     <input name="CE0" num_pins="1"/>
     <input name="CE1" num_pins="1"/>
     <clock name="I0" num_pins="1"/>
     <clock name="I1" num_pins="1"/>
     <input name="IGNORE0" num_pins="1"/>
     <input name="IGNORE1" num_pins="1"/>
     <input name="S0" num_pins="1"/>
     <input name="S1" num_pins="1"/>
     <mode name="EMPTY">
       <pb_type name="empty" blif_model=".latch" num_pb="1" />
       <interconnect />
     </mode>
     <mode name="BUFGCTRL">
       <pb_type name="BUFGCTRL_VPR" blif_model=".subckt BUFGCTRL_VPR" num_pb="1">
         <output name="O" num_pins="1"/>
         <input name="CE0" num_pins="1"/>
         <input name="CE1" num_pins="1"/>
         <clock name="I0" num_pins="1"/>
         <clock name="I1" num_pins="1"/>
         <input name="IGNORE0" num_pins="1"/>
         <input name="IGNORE1" num_pins="1"/>
         <input name="S0" num_pins="1"/>
         <input name="S1" num_pins="1"/>
         <metadata>
           <meta name="fasm_params">
             ZPRESELECT_I0 = ZPRESELECT_I0
             ZPRESELECT_I1 = ZPRESELECT_I1
             IS_IGNORE0_INVERTED = IS_IGNORE0_INVERTED
             IS_IGNORE1_INVERTED = IS_IGNORE1_INVERTED
             ZINV_CE0 = ZINV_CE0
             ZINV_CE1 = ZINV_CE1
             ZINV_S0 = ZINV_S0
             ZINV_S1 = ZINV_S1
           </meta>
         </metadata>
       </pb_type>
       <interconnect>
         <direct name="O" input="BUFGCTRL_VPR.O" output="BLK-TL-BUFGCTRL.O"/>
         <direct name="CE0" input="BLK-TL-BUFGCTRL.CE0" output="BUFGCTRL_VPR.CE0"/>
         <direct name="CE1" input="BLK-TL-BUFGCTRL.CE1" output="BUFGCTRL_VPR.CE1"/>
         <direct name="I0" input="BLK-TL-BUFGCTRL.I0" output="BUFGCTRL_VPR.I0"/>
         <direct name="I1" input="BLK-TL-BUFGCTRL.I1" output="BUFGCTRL_VPR.I1"/>
         <direct name="IGNORE0" input="BLK-TL-BUFGCTRL.IGNORE0" output="BUFGCTRL_VPR.IGNORE0"/>
         <direct name="IGNORE1" input="BLK-TL-BUFGCTRL.IGNORE1" output="BUFGCTRL_VPR.IGNORE1"/>
         <direct name="S0" input="BLK-TL-BUFGCTRL.S0" output="BUFGCTRL_VPR.S0"/>
         <direct name="S1" input="BLK-TL-BUFGCTRL.S1" output="BUFGCTRL_VPR.S1"/>

       </interconnect>
       <metadata>
         <meta name="fasm_features">
           IN_USE
         </meta>
       </metadata>
     </mode>
   </pb_type>

A correctly prepared techmap for any VPR model contains a declaration of
the module that should be substituted. Inside the module declaration, one
should provide a necessary logic and instantiate another module that
will substitute its original version. Additionally, all equations within
a techmap that are not used directly in a module instantiation should evaluate
to a constant value. Therefore most of the techmaps use additional constant
parameters to modify the signals attached to the instantiated module.

Here is a piece of a techmap, which instructs Yosys to convert
a ``BUFG`` primitive to the ``BUFGCTRL_VPR``. In this case, the techmaping process
consists of two steps. Firstly, the techmap shows how to translate the ``BUFG``
primitive to the ``BUFGCTRL``. Then how to translate the ``BUFGCTRL`` to
the ``BUFGCTRL_VPR``:

.. code-block:: verilog

   module BUFG (
     input I,
     output O
     );

     BUFGCTRL _TECHMAP_REPLACE_ (
       .O(O),
       .CE0(1'b1),
       .CE1(1'b0),
       .I0(I),
       .I1(1'b1),
       .IGNORE0(1'b0),
       .IGNORE1(1'b1),
       .S0(1'b1),
       .S1(1'b0)
     );
   endmodule

   module BUFGCTRL (
   output O,
   input I0, input I1,
   input S0, input S1,
   input CE0, input CE1,
   input IGNORE0, input IGNORE1
   );

     parameter [0:0] INIT_OUT = 1'b0;
     parameter [0:0] PRESELECT_I0 = 1'b0;
     parameter [0:0] PRESELECT_I1 = 1'b0;
     parameter [0:0] IS_IGNORE0_INVERTED = 1'b0;
     parameter [0:0] IS_IGNORE1_INVERTED = 1'b0;
     parameter [0:0] IS_CE0_INVERTED = 1'b0;
     parameter [0:0] IS_CE1_INVERTED = 1'b0;
     parameter [0:0] IS_S0_INVERTED = 1'b0;
     parameter [0:0] IS_S1_INVERTED = 1'b0;

     parameter _TECHMAP_CONSTMSK_IGNORE0_ = 0;
     parameter _TECHMAP_CONSTVAL_IGNORE0_ = 0;
     parameter _TECHMAP_CONSTMSK_IGNORE1_ = 0;
     parameter _TECHMAP_CONSTVAL_IGNORE1_ = 0;
     parameter _TECHMAP_CONSTMSK_CE0_ = 0;
     parameter _TECHMAP_CONSTVAL_CE0_ = 0;
     parameter _TECHMAP_CONSTMSK_CE1_ = 0;
     parameter _TECHMAP_CONSTVAL_CE1_ = 0;
     parameter _TECHMAP_CONSTMSK_S0_ = 0;
     parameter _TECHMAP_CONSTVAL_S0_ = 0;
     parameter _TECHMAP_CONSTMSK_S1_ = 0;
     parameter _TECHMAP_CONSTVAL_S1_ = 0;

     localparam [0:0] INV_IGNORE0 = (
         _TECHMAP_CONSTMSK_IGNORE0_ == 1 &&
         _TECHMAP_CONSTVAL_IGNORE0_ == 0 &&
         IS_IGNORE0_INVERTED == 0);
     localparam [0:0] INV_IGNORE1 = (
         _TECHMAP_CONSTMSK_IGNORE1_ == 1 &&
         _TECHMAP_CONSTVAL_IGNORE1_ == 0 &&
         IS_IGNORE1_INVERTED == 0);
     localparam [0:0] INV_CE0 = (
         _TECHMAP_CONSTMSK_CE0_ == 1 &&
         _TECHMAP_CONSTVAL_CE0_ == 0 &&
         IS_CE0_INVERTED == 0);
     localparam [0:0] INV_CE1 = (
         _TECHMAP_CONSTMSK_CE1_ == 1 &&
         _TECHMAP_CONSTVAL_CE1_ == 0 &&
         IS_CE1_INVERTED == 0);
     localparam [0:0] INV_S0 = (
         _TECHMAP_CONSTMSK_S0_ == 1 &&
         _TECHMAP_CONSTVAL_S0_ == 0 &&
         IS_S0_INVERTED == 0);
     localparam [0:0] INV_S1 = (
         _TECHMAP_CONSTMSK_S1_ == 1 &&
         _TECHMAP_CONSTVAL_S1_ == 0 &&
         IS_S1_INVERTED == 0);

     BUFGCTRL_VPR #(
         .INIT_OUT(INIT_OUT),
         .ZPRESELECT_I0(PRESELECT_I0),
         .ZPRESELECT_I1(PRESELECT_I1),
         .IS_IGNORE0_INVERTED(!IS_IGNORE0_INVERTED ^ INV_IGNORE0),
         .IS_IGNORE1_INVERTED(!IS_IGNORE1_INVERTED ^ INV_IGNORE1),
         .ZINV_CE0(!IS_CE0_INVERTED ^ INV_CE0),
         .ZINV_CE1(!IS_CE1_INVERTED ^ INV_CE1),
         .ZINV_S0(!IS_S0_INVERTED ^ INV_S0),
         .ZINV_S1(!IS_S1_INVERTED ^ INV_S1)
     ) _TECHMAP_REPLACE_ (
       .O(O),
       .CE0(CE0 ^ INV_CE0),
       .CE1(CE1 ^ INV_CE1),
       .I0(I0),
       .I1(I1),
       .IGNORE0(IGNORE0 ^ INV_IGNORE0),
       .IGNORE1(IGNORE1 ^ INV_IGNORE1),
       .S0(S0 ^ INV_S0),
       .S1(S1 ^ INV_S1)
     );

    endmodule

.. note::

   All F4PGA techmaps for Xilinx 7-Series devices use special inverter
   logic that converts constant 0 signals at the BEL to constant-1 signals
   at the site. This behavior is desired since VCC is the default signal in
   7-Series and US/US+ devices. The presented solution matches the conventions
   used by the vendor tools and gives the opportunity to validate generated
   bitstreams with fasm2bels and Vivado.

Yosys provides special techmapping naming conventions for wires,
parameters, and modules. The special names that start with ``_TECHMAP_``
can be used to force certain behavior during the techmapping process.
Currently, the following special names are used in F4PGA techmaps:

- ``_TECHMAP_REPLACE_`` is used as a name for an instantiated module, which will
  replace the one used in the original design. This special name causes
  the instantiated module to inherit the name and all attributes
  from the module that is being replaced.

- ``_TECHMAP_CONSTMSK_<port_name>_`` and ``_TECHMAP_CONSTVAL_<port_name>_``
  are used together as names of parameters. The ``_TECHMAP_CONSTMASK_<port_name>_``
  has a length of the input signal. Its bits take the value 1 if
  the corresponding signal bit has a constant value, or 0 otherwise.
  The ``_TECHMAP_CONSTVAL_<port_name>_`` bits store the actual constant signal
  values when the ``_TECHMAP_CONSTMASK_<port_name>_`` is equal to 1.

More information about special wire, parameter, and module names can be found in
`techmap section in the Yosys Manual`_.

.. note::

   Techmapping can be used not only to change the names of the primitives
   but primarily to match the port declarations and express the logic behind
   the primitive substitution:

   .. verilog:module:: module BUFG (output O, input I)

   .. verilog:module:: module BUFGCTRL (output O, input CE0, input CE1, input I0, input I1, input IGNORE0, input IGNORE1, input S0, input S1)

More information
----------------

Additional information about Yosys can be found on the `Yosys Project Website
<https://yosyshq.net/yosys/>`_ , or in `Yosys Manual
<https://yosyshq.net/yosys/files/yosys_manual.pdf>`_. You can also compile
one of the tests described in Getting Started section and watch the log file
to understand which operations are performed by Yosys.

Place & Route
*************

The F4PGA Project uses two different tools for the PnR process - ``nextpnr`` and ``Versatile Place and Route`` (VPR).
Both of them write their final result to a file in the ``.fasm`` format.

VPR
===

See `VPR ➚ <https://docs.verilogtorouting.org/en/latest/vpr/>`__.

nextpnr
=======

See :gh:`nextpnr ➚ <f4pga/nextpnr>`.
