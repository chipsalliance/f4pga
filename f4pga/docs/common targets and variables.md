# sfbuild's common targets and values

Targets and values are named with some conventions.
Below are lists of the target and value names along with their meanings"

### Common targets that need to be provided by the user:

| Target name | list | Description |
|-------------|:----:|-------------|
| `sources` | yes | Verilog sources |
| `sdc` | no | Synopsys Design Constraints |
| `xdc` | yes | Xilinx Design Constraints (available only for Xilinx platforms) |
| `pcf` | no | Physical Constraints File |

### Commonly requested targets (available in most flows):

| Target name | list | Description |
|-------------|:----:|-------------|
| `eblif` | no | Extended blif file |
| `bitstream` | no | Bitstream |
| `net` | no | Netlist |
| `fasm` | no | Final FPGA Assembly |
| `fasm_extra` | no | Additional FPGA assembly that may be generated during synthesis |
| `build_dir` | no | A directory to put the output files in |

### Built-in values

| Value name | type | Description |
|------------|------|-------------|
| `shareDir` | `string` | Path to symbiflow's installation "share" directory |
| `python3` | `string` | Path to Python 3 executable |
| `noisyWarnings` | `string` | Path to noisy warnings log (should be deprecated) |
| `prjxray_db` | `string` | Path to Project X-Ray database |

### Values commonly used in flow definitions:

| Value name | type | Description |
|------------|------|-------------|
| `top` | `string` | Top module name |
| `build_dir` | `string` | Path to build directory (should be optional) |
| `device` | `string` | Name of the device |
| `vpr_options` | `dict[string -> string \| number]` | Named ptions passed to VPR. No `--` prefix included. |
| `part_name` | `string` | Name of the chip used. The distinction between `device` and `part_name` is ambiguous at the moment and should be addressed in the future. |
| `arch_def` | `string` | Path to an XML file containing architecture definition. |
