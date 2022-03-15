In F4PGA
########

Synthesis
=========

In the F4PGA toolchain synthesis is made with the use of Yosys, that is able to perform all the mentioned steps and
convert HDL to netlist description.
The result of these steps is written to a file in ``.eblif`` format.

Place & Route
=============

The F4PGA Project uses two different tools for the PnR process - ``nextpnr`` and ``Versatile Place and Route`` (VPR).
Both of them write their final result to a file in the ``.fasm`` format.
