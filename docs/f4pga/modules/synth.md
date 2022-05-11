# synth

The _synth_ module is meant to be used to execute YOSYS synthesis.

The module should guarantee the following outputs:
 * `eblif`
 * `fasm_extra` (can be empty)
 * `json`
 * `synth_json`
 * `synth_log` (on demand)

For detailed information about these targets, please refer to
`docs/common targets and variables.md`

What files and how are they generated is dependent on TCL scripts executed
withing YOSYS and the script vary depending on the target platform. Due to this
design choice it is required for the author of the flow definition to parameterize
the `synth` module in a way that will **GUARANTEE** the targets mentioned above
will be generated upon a successful YOSYS run.

The setup of the synth module follows the following specifications:

## Parameters

The `params` section of a stage configuration may contain a `produces` list.
The list should specify additional targets that will be generated
(`?` qualifier is allowed).

## Values

The `synth` module requires the following values:

* `tcl_scripts` (string, required): A path to a directory containing `synth.tcl`
  and `conv.tcl` scripts that will be used by YOSYS.
* `read_verilog_args` (list[string | number], optional) - If specified, the Verilog
  sources will be read using the `read_verilog` procedure with options contained in
  this value.
* `yosys_tcl_env` (dict[string -> string | list[string], required) - A mapping that
  defines environmental variables that will be used within the TCL scripts. This
  should contain the references to module's inputs and outputs in order to guarantee
  the generation of the desired targets.
