yosys -import

plugin -i sdc

yosys -import

read_verilog $::env(DESIGN_TOP).v
synth_xilinx
create_clock -period 10 clk
propagate_clocks
write_sdc $::env(DESIGN_TOP)_1.sdc
write_json $::env(DESIGN_TOP).json

design -push
read_json $::env(DESIGN_TOP).json
write_sdc $::env(DESIGN_TOP)_2.sdc
