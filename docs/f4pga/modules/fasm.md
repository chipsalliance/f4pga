# fasm

The _fasm_ module generates FPGA assebly using `genfasm` (VPR-only).

The module should guarantee the following outputs:
 * `fasm`

For detailed information about these targets, please refer to
`docs/common targets and variables.md`

The setup of the synth module follows the following specifications:

## Values

The `fasm` module accepts the following values:

* `pnr_corner` (string, optional): PnR conrenr to use. Relevant only for Quicklogic's
  eFPGAs.