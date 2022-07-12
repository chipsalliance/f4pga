# SystemVerilog Plugin

Reads SystemVerilog and UHDM files and processes them into Yosys AST.

The plugin adds the following commands:

* `read_systemverilog`
* `read_uhdm`

A more detailed help on the supported commands can be obtained by running `help <command_name>` in Yosys.

Please see the dedicated [integration repository](https://github.com/antmicro/yosys-uhdm-plugin-integration) which contains more information about installation and usage of this plugin.
This repository also runs dedicated CI pipelines that perform extensive testing of this plugin.

## Installation

A pre-built binary can be downloaded from the [release page](https://github.com/antmicro/yosys-uhdm-plugin-integration/releases).
The release archive contains an installation script that detects Yosys installation and installs the plugin.

To build from sources please refer to the [integration repository](https://github.com/antmicro/yosys-uhdm-plugin-integration).

## Usage

Usage of the plugin is very simple.

This paragraph describes the synthesis process given the following `counter.sv` file:

```
module top (
  input clk,
  output [3:0] led
);
  localparam BITS = 4;
  localparam LOG2DELAY = 22;

  wire bufg;
  BUFG bufgctrl (
      .I(clk),
      .O(bufg)
  );
  reg [BITS+LOG2DELAY-1:0] counter = 0;
  always @(posedge bufg) begin
    counter <= counter + 1;
  end
  assign led[3:0] = counter >> LOG2DELAY;
endmodule
```

To load the plugin, execute `plugin -i systemverilog`.
Then to load SystemVerilog sources, execute `read_systemverilog`.
The rest of the flow is exactly the same as without the plugin.

To synthesize the `counter.sv` file:

```
yosys> plugin -i systemverilog
yosys> read_systemverilog  counter.v
1. Executing Verilog with UHDM frontend.
[INF:CM0023] Creating log file ./slpp_all/surelog.log.
[WRN:PA0205] counter.v:1: No timescale set for "top".
[INF:CP0300] Compilation...
[INF:CP0303] counter.v:1: Compile module "work@top".
(...)
Generating RTLIL representation for module `\top'.

yosys> synth_xilinx

2. Executing SYNTH_XILINX pass.

(...)

3.50. Printing statistics.

=== top ===

   Number of wires:                 10
   Number of wire bits:            167
   Number of public wires:           4
   Number of public wire bits:      32
   Number of memories:               0
   Number of memory bits:            0
   Number of processes:              0
   Number of cells:                 40
     BUFG                            1
     CARRY4                          7
     FDRE                           26
     IBUF                            1
     INV                             1
     OBUF                            4

   Estimated number of LCs:          0

3.51. Executing CHECK pass (checking for obvious problems).
Checking module top...
Found and reported 0 problems.

yosys> write_edif counter.edif

4. Executing EDIF backend.

```
As a result we get a `counter.edif` file that can be further processed to get the bitstream.

### Parsing multiple files
When parsing multiple files you can either pass them together to the `read_systemverilog` command
or read them one by one using `-defer` flag. In the latter case, you will need to call 
`readsystemverilog -link` after processing all files to elaborate them. An example flow would
look like below:
```
plugin -i systemverilog
# Read each file separately
read_systemverilog -defer dut.sv
read_systemverilog -defer top.sv
# Finish reading files, elaborate the design
read_systemverilog -link
# Continue Yosys flow...
```
