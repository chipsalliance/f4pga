# f4pga python package

This is the current in-development FPGA-oriented build system that's provided with f4pga.

This package aims to provide a unified front-end for executing _verilog-to-bitstream_ and
other flows for various FPGA platforms. It's meant as a future replacement of
`symbiflow_*` shell scripts.

It contains _EDA_ tool wrappers that provide meta-data about the tools, utilities 
related to tracking files and inspection of data used within the flows, scripts used by
tools within flows, a dependency resolution algorithm and flow templates for various devices.

The basic usage requires creation of a `flow.json` file describing the FPGA-oriented project.
You can take
[one from the f4pga-examples repository](https://github.com/chipsalliance/f4pga-examples/blob/main/xc7/counter_test/flow.json)
as a reference. Alternatively there's a way to configure a flow with command-line parameters only.

Once you have your flow created, run

```
f4pga build -f flow.json 
```

to build a default target.

To learn more about the package and its usage, visit
[related section in the docs](https://f4pga.readthedocs.io/en/latest/f4pga/index.html).

--------------------------------------------------

## Package capability status:

* Architecture support:
    * Xilinx XC7 (**available** in main branch)
        * Synthesis tool: yosys
        * PnR tool: VPR
        * bitstream generation: yes (xcfasm)
        * used in f4pga-examples:
        [yes](https://github.com/chipsalliance/f4pga-examples/blob/main/xc7/counter_test/flow.json)
    * Quicklogic EOS-S3 (yosys+VPR flow) (**WIP**, see
    [#577](https://github.com/chipsalliance/f4pga/pull/577))
        * Synthesis tool: yosys
        * PnR tool: VPR
        * bitstream generation: yes (qlfasm)
        * analysis: ?
        * used in f4pga-examples: no
    * Lattice ICE40 (yosys+nextpnr flow) (**WIP**, see
    [#585](https://github.com/chipsalliance/f4pga/pull/585))
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

## Contributing

We welcome contributions from all people as long as they don't include any discriminatory, hateful
language, don't force users to use proprietary technologies and are related to the F4PGA project.

We will prioritize contributions which serve to improve support for platforms that are
officially supported by _f4pga_. UX-related contributions are welcome as well.

## Reporting bugs

If you find a bug and want other to take a look, please open an issue, attach a log and a minimal
example for reproducing the bug. Use `-vv` (maximum verbosity level) option when running `f4pga`
if possible.

Please, remember to specify the version of architecture definitions you are using (this applies only to VPR-based flows).
If you used a pre-built packages, please provide a hash that identifies the package and name
of the platform in question (_XC7_/_EOS-S3_).
The hash is the last alphanumeric component before the `.tar.gz` suffix of the archive with
prebuilt packages. Use your local installation to look-up the hash. Links to packages in
[the documention](https://f4pga-examples.readthedocs.io/en/latest/getting.html) get automatically
updated to point to the latest packages.

If you built the architecture definitions yourself, please specify the hash of the commit you've
used.

If you don't specify the version of architecture definitions, we might be unable to reproduce the 
bug.

## Licensing

f4pga is a Free Open-Source Software licensed under Apache 2.0 license.

