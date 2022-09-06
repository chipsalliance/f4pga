# Netlist repacking utility

## 1. Goal

Provide the same VPR operating mode pb_type into physical mode pb_type
repacking as implemented in the OpenFPGA project.

https://openfpga.readthedocs.io/en/master/manual/openfpga_shell/openfpga_commands/fpga_bitstream_commands/#repack

## 2. Files affected by the repacker

The utility expects a VPR packed netlist, an EBLIF netlist and a VPR placement
file as input and outputs a similar set of files representing the design after
repacking. The placement is not altered, just the SHA checksum is updated in
the file.

### VPR packed netlist (.net)

The packed netlist contains information about the clusters of a packed design.
It tells which specific pb_type instances (pbs or blocks) are occupied by which
cells from the circuit netlist. Intra-cluster routing as well as LUT port
rotation is also stored there.

The repacker discards any existing intra-cluster routing, remaps blocks and
their port connections according to rules provided by OpenFPGA architecture
file and re-routes the cluster. The procedure is repeated for each cluster
independently.

### Circuit netlist (.blif / .eblif)

The circuit netlist holds all nets and cells of a particular design along with
its attributes and parameters. Repacking a cell from one block instance into
another usually requires changing its type. All changes introduced to the
packed netlist must be reflected in the circuit netlist hence it needs to be
modified by the packer as well.

### VPR placement file (.place)

This file stores cluster placement on the device grid. The file content itself
is not affected by the packer but its header is. The header stores a checksum
computed over the packed netlist file to ensure that the two stays in sync.
Modified packed netlist has a different checksum hence the placement file
needs to have its header updated.

## 4. Tool operation

### Preparation

The preparation step includes loading and pre-processing all the information
required for repacking

#### loading of VPR architecture

The VPR architecture XML file is loaded to obtain information about:
 - pb_type hierarchy
 - binding of netlist cell types (BLIF models) with pb_types
 - cell models used in the architecture.

Soon after the architecture file is read an internal representation of the
pb_type hierarchy for each root pb_type (a.k.a. complex block - CLB) is built.
For every leaf pb_type of class "lut" another child pb_type is added to the
hierarchy. This is done to keep the pb_type hierarchy consistent with the packed
netlist hierarchy where native LUTs contain the one extra level.

Next, all known leaf pb_types are scanned for cell type bindings and internal
structures that represent known cell types are created. VPR architecture does
not store port widths along with the model list so to get actual cell types
both pb_type tree and the model list need to be examined.

#### Loading of repacking rules

Repacking rules may contain port maps. These port maps may or may not
explicitly specify port pins (bits). For the purpose of the repacker
implementation port map needs to be known down to each pin. To tell the
pin-to-pin correspondence each rule is confronted with the pb_type it refers to
(pb_types store port widths) and direct pin correspondences are created.
This is called "port map expansion".

#### Loading and pre-processing of circuit netlist

The circuit BLIF/EBLIF netlist is loaded and stored internally.

A netlist contains top-level ports. These ports do not correspond to any cells.
However, they will have to be represented by explicit netlist cells after
repacking. To allow for that each top-level port is converted to a virtual cell
and added to the netlist. This allows the repacking algorithm to operate
regularly without the need of any special IO handling. Top-level netlist ports
are removed.

#### Circuit netlist cleaning

Circuit netlist cleaning (for now) includes removal of buffer LUTs. Buffer LUTs
are 1-bit LUTs configured as pass-through. They are used to stitch different
nets together while preserving their original names. The implemented buffer LUT
absorption matches the identical process performed by VPR and should be enabled
for the repacker if enabled for the VPR flow.

#### Loading of the packed netlist

The packed netlist is loaded, parsed and stored using internal data structures

### Repacking

The repacking is done independently for each cluster. Clusters are processed
one-by-one, repacked ones replace original ones in the packed netlist. The
following steps are identical and are done in the same sequence for each
cluster.

#### Net renaming
Net renaming is a result of LUT buffer absorption. This is necessary to keep
the packed netlist and the circuit netlist in sync.

#### Explicit instantiation of route-through LUTs
In VPR a native LUT (.names) can be configured as an implicit buffer
(a route-through) by the VPR packer whenever necessary. Such a lut is not
present in the circuit netlist. However it still needs to be repacked into a
physical LUT cell.

To achieve this goal all route-though LUTs in the packed netlist of the current
cluster are identifier and explicit LUT blocks are inserted for them. After
that corresponding LUT buffers are inserted into the circuit netlist. This
ensures regularity of the repacking algorithm - no special handling is required
for such LUTs. They will be subjected to repacking as any other block/cell.

#### Identification of blocks to be repacked and their targets

In the first step all blocks that are to be repacked are identified. For this
the packed netlist of the cluster is scanned for leaf blocks. Each leaf block
is compared against all known repacking rules. Whenever its path in the
hierarchy matches a rule then it is considered to be repacked. Identified
blocks are stored along with their matching rules on a list.

The second step is identification of target (destination) block(s) for each
source block for the repacking to take place. To do that a function scans the
hierarchy of the VPR architecture and identifies pb_types that match the
destination path as defined by the repacking rule for the given block. A list of
destination pb_types is created. The list should contain exactly one element.
Zero elements means that there is no suitable pb_type present in the
architecture and more than one means that there is an ambiguity. Both cases are
reported as an error. Finally the destination pb_type is stored along with the
block to be repacked.

If there are no blocks to be repacked then there is nothing more that can be
done for this cluster and the algorithm moves to the next one.

#### Circuit netlist cell repacking

For each block to be repacked its corresponding cell instance in the circuit
netlist and its cell type (model) is found. Cell type (model) of the destination
pb_type is identified as well. The original cell is removed from the circuit
netlist and a new one is created based on the destination pb_type model. The new
cell connectivity is determined by the port map as defined by the repacking rule
being applied. For LUTs the LUT port rotation is also taken into account here.

In case of a LUT the newly created LUT cell receives a parameter named "LUT"
which stores the truth table.

If the block being repacked represents a top-level IO port then the port name is
added to the list of top-level ports to be removed. When a top-level IO is
repacked into a physical cell, no top-level IO port is needed anymore.

#### Cluster repacking

Repacking of cluster cells (in the packed netlist) is done implicitly via the
pb_type routing graph. Routes present in the graph imply which blocks are used
(instanced) and which are not. The advantage of that approach is that the
repacking and rerouting of the cluster are both done at the same single step.

At the beginning the routing graph for the complex block is created. The graph
represents all routing resources for a root pb_type (complex block) as defined
in the VPR architecture. In the graph nodes represent pb_type ports and edges
connections between them. Nodes may be associated with nets. Edges are
associated with nets implicitly - if an edge spans two nodes of the same net
then it also belongs to that net.

Once the graph is built all nodes representing ports of the destination blocks
of the remapping are associated with net names. Ports are remapped according to
the repacking rules. This is the step where the actual repacking takes place.
Together with the repacked blocks the ports of the cluster block are associated
with nets as well.

Following port and net association there is the routing stage. For each node
that is a sink a route to the source node of the same net is determined.
In case when the source node is a cluster block port and there is no route
available the first cluster block port node that can be reached is taken. This
works similarly to the VPR packer.

Currently the router is implemented as a greedy depth-first search. No edge
timing information is used. For the complexity of the current repacking problems
this implementation is sufficient - most of the routing paths do not have more
than one or two alternatives.

Finally once the graph is fully routed it is converted back to a packed netlist
of the cluster. The new cluster replaces the old one in the packed netlist.

#### IO blocks handling

During conversion from packed netlist to a routing graph and back information
about IO block names is lost. To preserve the names the original ones are stored
prior to the cluster repacking and are used to rename repacked IO blocks
afterwards.

### Finishing

At this point all clusters were repacked along with the corresponding cells in
the circuit netlist. Apart from writing the data to files there are a few
additional steps that need to be performed.

#### Top-level port removal
During cluster processing names of blocks representing top-level IO ports were
stored. Those blocks got repacked into physical IO cells and the top-level IO
ports are no longer needed so they are removed.

#### Synchronization of cells attributes and parameters

VPR stores cell attributes and parameters read from the circuit (EBLIF) netlist
with the packed netlist as well. It complains if both don't match. During
conversion from packed netlist to a routing graph and back block attributes and
parameters are lost - they are not stored within the graph. So in this step they
are taken from the circuit netlist and associated with corresponding packed
netlist blocks again.

#### Circuit netlist cleaning

This step is necessary only if buffer LUT absorption is enabled. Before
repacking buffer LUTs driving top-level ports cannot be removed as their removal
would cause top-level IO port renaming. After repacking IO ports are represented
as cells so the removal is possible.

#### Circuit netlist write back (EBLIF)

The circuit netlist is written to an EBLIF file. The use of the EBLIF format is
necessary to store LUT truth tables as cell parameters. After repacking LUTs are
no longer represented by .names hence require a parameter to store the truth
table.

#### Packed netlist write back

This is an obvious step. The final packed netlist is serialized and written to
an XML (.net) file.

#### Patching of VPR placement file
If provided, the VPR placement file receives a patched header containing a new
SHA256 checksum. The checksum corresponds to the packed netlist file after
repacking.

## Implementation

The repacker is implemented using a set of Python scripts located under quicklogic/openfpga/utils.

 * repack.py

    This is the main repacking script that implements the core repacking algorithm steps. This one is to be invoked to perform repacking.

 * pb_rr_graph.py

    Utilities for representing and building pb_type routing graph based on VTR architecture

 * pb_rr_graph_router.py

    Implementation of a router which operates on the pb_type routing graph.

 * pb_rr_graph_netlist.py

    A set of utility functions for loading a packed netlist into a pb_type graph as well as for creating a packed netlist from a routed pb_type graph.

 * pb_type.py

    Data structures and utilities for representing the pb_type hierarchy

 * netlist_cleaning.py

    Utilities for cleaning circuit netlist

 * packed_netlist.py

    Utilities for reading and writing VPR packed netlist

 * eblif.py

    Utilities for reading and writing BLIF/EBLIF circuit netlist

 * block_path.py

    Utilities for representing hierarchical path of blocks and pb_types

## Important notes

### Circuit netlist cleaning

VPR can "clean" a circuit netlist and it does that by default.
The cleaning includes:

 * Buffer LUT absorption
 * Dangling block removal
 * Dangling top-level IO removal

The important issue is that normally the cleaned netlist is not written back
to any file hence it cannot be accessed outside VPR. That cleaned circuit
netlist must correspond to the packed netlist used. This means equal number of
blocks and cells and matching names.

The issue is that the circuit netlist input to the repacker is not the actual
netlist used by VPR that has to match with the packed netlist.

An obvious solution would be to disable all netlist cleaning operations in VPR.
But that unfortunately leads to huge LUT usage as each buffer LUT is then
treated by VPR as a regular cell.

An alternative solution, which has been implemented, is to recreate some of
the netlist cleaning procedures in the repacker so that they both operate on
the same effective circuit netlist. This is what has been done.
