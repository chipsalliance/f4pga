.. _Flows:

Introduction
============

This section provides a description of the F4PGA toolchain as well as the basic concepts of the FPGA design flow.

F4PGA is an end-to-end FPGA synthesis toolchain, because of that it provides all the necessary tools to convert input
Hardware Description Language (HDL) sources into a final bitstream.
It is simple to use however, the whole synthesis and implementation process is not trivial.

The final bitstream format depends on the used platform.
What's more, every platform has different resources and even if some of them provide similar functionality, they can be
implemented in a different way.
In order to be able to match all that variety of possible situations, the creation of the final bitstream is divided
into few steps.
F4PGA uses different programs to create the bitstream and is responsible for their proper integration.
The procedure of converting HDL files into the bitstream is described in the next sections.

.. figure:: ../_static/images/toolchain-flow.svg
    :align: center

    F4PGA Toolchain design flow
