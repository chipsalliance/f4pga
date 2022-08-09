Package capability status
#########################

* Architecture support:

    * Xilinx XC7 (**available** in main branch)

        * Synthesis tool: yosys

        * PnR tool: VPR

        * bitstream generation: yes (xcfasm)

        * used in f4pga-examples: :gh:`yes <chipsalliance/f4pga-examples/blob/main/xc7/counter_test/flow.json>`

    * Quicklogic EOS-S3 (yosys+VPR flow) (**WIP**, see :ghsharp:`577`)

        * Synthesis tool: yosys

        * PnR tool: VPR

        * bitstream generation: yes (qlfasm)

        * analysis: ?

        * used in f4pga-examples: no

    * Lattice ICE40 (yosys+nextpnr flow) (**WIP**, see :ghsharp:`585`)

        * Synthesis tool: yosys

        * PnR tool: nextpnr

        * bitstream generation: yes (icepack)

        * used in f4pga-examples: no

    * Quicklogic k4n8 (Unverified, not officially supported. Might work after some tinkering.)

        * Synthesis tool: yosys

        * PnR tool: VPR

        * bitstream generation: yes (qlf_fasm)

        * used in f4pga-examples: no

* Incremental builds support

* Support for multiple configurations for a single project

* Can be used as a python interface to _F4PGA_, however there's no official _API_ at the moment.
