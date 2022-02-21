FPGA Design Flow
================

SymbiFlow is an end-to-end FPGA synthesis toolchain, because of that it provides
all the necessary tools to convert input Verilog design into a final bitstream.
It is simple to use however, the whole synthesis and implementation process
is not trivial.

The final bitstream format depends on the used platform.
What's more, every platform has different resources and even if some of them
provide similar functionality, they can be implemented in a different way.
In order to be able to match all that variety of possible situations,
the creation of the final bitstream is divided into few steps.
SymbiFlow uses different programs to create the bitstream and is
responsible for their proper integration. The procedure of converting
Verilog file into the bitstream is described in the next sections.

.. figure:: ../_static/images/toolchain-flow.svg
    :align: center

    Symbiflow Toolchain design flow

Synthesis
---------

Synthesis is the process of converting input Verilog file into a netlist,
which describes the connections between different block available on the
desired FPGA chip. However, it is worth to notice that these are only
logical connections. So the synthesized model is only a draft of the final
design, made with the use of available resources.

RTL Generation
++++++++++++++

the input Verilog file is often really complicated. Usually it is  written in
a way that it is hard to distinguish the digital circuit standing behind
the implemented functionality. Designers often use a so-called
*Behavioral Level* of abstraction, in their designs, which means that the whole
description is mostly event-driven. In Verilog, support for behavioral models
is made with use of ``always`` statements.

However, FPGA mostly consist of Look Up Tables (LUT) and flip-flops.
Look Up Tables implement only the functionality of logic gates.
Due to that, the synthesis process has to convert the complicated
Behavioral model to a simpler description.

Firstly, the design is described in terms of registers and logical operations.
This is the so-called *Register-Transfer Level* (*RTL*).
Secondly, in order to simplify the design even more, some complex logic is
rewritten in the way that the final result contain only logic gates
and registers. This model is on *Logical Gate level* of abstraction.

The process of simplification is quite complicated, because of that it often
demands additional simulations between mentioned steps to prove that the input
design is equivalent to its simplified form.

Technology mapping
++++++++++++++++++

FPGAs from different architectures may have different architecture. For example,
they may contain some complicated functional blocks (i.e. RAM, DSP blocks)
and even some of the basic blocks like LUT tables and flip-flops may vary
between chips. Because of that, there is a need to describe the final design
in terms of platform-specific resources. This is the next step in the process
of synthesis. The simplified description containing i.e. logic gates, flip-flops
and a few more complicated blocks like RAM is taken and used "general" blocks
are substituted with that physically located in the chosen FPGA.
The vendor-specific definitions of these blocks are often located
in a separate library.

Optimization
++++++++++++

Optimization is the key factor that allows to better utilize resources
of an FPGA. There are some universal situations in which the design
can be optimized, for example by substituting a bunch of logic gates
in terms of fewer, different gates. However, some operations can be performed
only after certain steps i.e. after technology mapping.
As a result, optimization is an integral part of most of the synthesis steps.

Synthesis in SymbiFlow
++++++++++++++++++++++

In the SymbiFlow toolchain synthesis is made with the use of Yosys,
that is able to perform all the mentioned steps and convert Verilog to netlist
description. The result of these steps is written to a file in ``.eblif``
format.

Place & Route
-------------

The Synthesis process results in an output containing logical elements
available on the desired FPGA chip with the specified connections between them.
However, it does not specify the physical layout of those elements in the
final design. The goal of the Place and Route (PnR) process is to take the
synthesized design and implement it into the target FPGA device. The PnR tool
needs to have information about the physical composition of the device, routing
paths between the different logical blocks and signal propagation timings.
The working flow of different PnR tools may vary, however, the process presented
below represents the typical one, adopted by most of these tools. Usually, it
consists of four steps - packing, placing, routing and analysis.

Packing
+++++++

In the first step, the tool collects and analyzes the primitives present
in the synthesized design (e.g. Flip-Flops, Muxes, Carry-chains, etc), and
organizes them in clusters, each one belonging to a physical tile of the device.
The PnR tool makes the best possible decision, based on the FPGA routing
resources and timings between different points in the chip.

Placing
+++++++

After having clustered all the various primitives into the physical tiles of the
device, the tool begins the placement process. This step consists in assigning a
physical location to every cluster generated in the packing stage. The choice of
the locations is based on the chosen algorithm and on the user's parameters, but
generally, the final goal is to find the best placement that allows the routing
step to find more optimal solutions.

Routing
+++++++

Routing is one of the most demanding tasks of the the whole process.
All possible connections between the placed blocks and the information on
the signals propagation timings, form a complex graph.
The tool tries to find the optimal path connecting all the placed
clusters using the information provided in the routing graph. Once all the nets
have been routed, an output file containing the implemented design is produced.

Analysis
++++++++

This last step usually checks the whole design in terms of timings and power
consumption.

Place & Route in SymbiFlow
++++++++++++++++++++++++++

The SymbiFlow Project uses two different tools for the PnR process - ``nextpnr``
and ``Versatile Place and Route`` (VPR). Both of them write their final result
to a file in the ``.fasm`` format.

Bitstream translation
---------------------

The routing process results in an output file specifying the used blocks
and routing paths. It contains the resources that needs to be instantiated
on the FPGA chip, however, the output format is not understood
by the FPGA chip itself.

In the last step, the description of the chip is translated into
the appropriate format, suitable for the chosen FPGA.
That final file contains instructions readable by the configuration block of
the desired chip.

Documenting the bitstream format for different FPGA chips is one of the
most important tasks in the SymbiFlow Project!
