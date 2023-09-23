Package capability status
#########################

* Supports incremental builds.

* Supports multiple configurations for a single project.

* Provides a Python interface to ``F4PGA``, however there's no official API at the moment.

Architectures and flows
=======================

Xilinx XC7
----------

* Synthesis tool: yosys
* PnR tool: VPR
* bitstream generation: yes (xcfasm)
* used in f4pga-examples: :gh:`yes <chipsalliance/f4pga-examples/blob/main/xc7/counter_test/flow.json>`

Quicklogic EOS-S3
-----------------

* Synthesis tool: yosys
* PnR tool: VPR
* bitstream generation: yes (qlfasm)
* analysis: ?
* used in f4pga-examples: no

Lattice ICE40
-------------

.. IMPORTANT::
   **WIP** :ghsharp:`585`

* Synthesis tool: yosys
* PnR tool: nextpnr
* bitstream generation: yes (icepack)
* used in f4pga-examples: no

Quicklogic k4n8
---------------

* Synthesis tool: yosys
* PnR tool: VPR
* bitstream generation: yes (qlf_fasm)
* used in f4pga-examples: no

.. NOTE::
  Unverified, not officially supported.
  Might work after some tinkering.
