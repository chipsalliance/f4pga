Place & Route
#############

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
=======

In the first step, the tool collects and analyzes the primitives present
in the synthesized design (e.g. Flip-Flops, Muxes, Carry-chains, etc), and
organizes them in clusters, each one belonging to a physical tile of the device.
The PnR tool makes the best possible decision, based on the FPGA routing
resources and timings between different points in the chip.

Placing
=======

After having clustered all the various primitives into the physical tiles of the
device, the tool begins the placement process. This step consists in assigning a
physical location to every cluster generated in the packing stage. The choice of
the locations is based on the chosen algorithm and on the user's parameters, but
generally, the final goal is to find the best placement that allows the routing
step to find more optimal solutions.

Routing
=======

Routing is one of the most demanding tasks of the whole process.
All possible connections between the placed blocks and the information on
the signals propagation timings, form a complex graph.
The tool tries to find the optimal path connecting all the placed
clusters using the information provided in the routing graph. Once all the nets
have been routed, an output file containing the implemented design is produced.

Analysis
========

This last step usually checks the whole design in terms of timings and power
consumption.
