Synthesis
#########

Synthesis is the process of converting input Verilog file into a netlist,
which describes the connections between different block available on the
desired FPGA chip. However, it is worth to notice that these are only
logical connections. So the synthesized model is only a draft of the final
design, made with the use of available resources.

RTL Generation
==============

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
==================

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
============

Optimization is the key factor that allows to better utilize resources
of an FPGA. There are some universal situations in which the design
can be optimized, for example by substituting a bunch of logic gates
in terms of fewer, different gates. However, some operations can be performed
only after certain steps i.e. after technology mapping.
As a result, optimization is an integral part of most of the synthesis steps.
