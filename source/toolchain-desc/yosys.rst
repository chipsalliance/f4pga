Yosys
=====

Yosys is a Free and Open Source Verilog HDL synthesis tool. It was designed
to be highly extensible and multiplatform. In SymbiFlow toolchain,
it is responsible for the whole synthesis process described in `FPGA Design Flow
<./design-flow.html>`_

It is not necessary to call Yosys directly using the SymbiFlow
toolchain. Nevertheless, the following description, should provide
sufficient introduction to Yosys usage inside the project.
It is also a good starting point for a deeper understanding of the whole
Toolchain.

Short description
-----------------

Yosys consists of several subsystems. Most distinguishable are the
first and last one used in the synthesis process, called respectively
*frontend* and *backend*. Intermediate subsystems are called *passes*.

The *frontend* is responsible for changing the Verilog input file into
internal Yosys, representation which is common for all *passes* used
by the program. The *passes* are responsible for variety of optimizations
(``opt_``) and simplifications (``proc_``).

Two *passes*, that are worth
to mention separately are ``ABC`` and ``techmap``. The first one optimizes
logic functions from the design and assigns obtained results into Look Up Tables
(LUTs) of chosen width. The second mentioned *pass* - ``techmap``
is responsible for mapping the synthesized design from Yosys internal
blocks to that located on FPGA chip including i.e. RAM, DSP and LUTs.
Recommended synthesis flows for different FPGAs are combined into
macros i.e. ``synth_ice40`` (for Lattice iCE40 FPGA) or ``synth_xilinx``
(for Xilinx 7-series FPGAs).

The *backend* on the other hand, is responsible
for converting internal Yosys representation into one of the standardized
formats. Symbiflow uses ``.eblif`` as its output file format.

Usage in Toolchain
------------------

All operations performed by Yosys are written  in ``.tcl`` script. Commands used
in the scripts are responsible for preparing output file to match with the
expectations of other toolchain tools.
There is no need to change it even for big designs.
Example of configuration script can be found below:

.. code-block:: tcl

    yosys -import

    synth_ice40 -nocarry

    opt_expr -undriven
    opt_clean

    setundef -zero -params
    write_blif -attr -cname -param $::env(OUT_EBLIF)
    write_verilog $::env(OUT_SYNTH_V)

It can be seen that this script perform a platform-specific process of
synthesis, some optimization steps (``opt_`` commands), and writes the final file in
``.eblif`` and Verilog formats. Yosys synthesis configuration scripts are platform-specific
and can by found in ``<platform-dir>/yosys/synth.tcl``
in `Symbiflow Architecture Definitions <https://github.com/SymbiFlow/symbiflow-arch-defs>`_
repository.

To understand performed operations it is worth to look at log file. Usually it
is generated in the project build directory. It should be named ``top.eblif.log``.

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

More information
----------------

Additional information about Yosys can be found on the `Yosys Project Website
<http://www.clifford.at/yosys/>`_ , or in `Yosys Manual
<http://www.clifford.at/yosys/files/yosys_manual.pdf>`_. You can also compile
one of the tests described in Getting Started section and watch the log file
to understand which operations are performed by Yosys.
