yosys -import
if { [info procs read_sdc] == {} } { plugin -i sdc }
yosys -import  ;# ingest plugin commands

read_verilog $::env(DESIGN_TOP).v
synth_xilinx
create_clock -period 10 clk
propagate_clocks

# Clean processes before writing JSON.
yosys proc

write_sdc [test_output_path "restore_from_json_1.sdc"]
write_json [test_output_path "restore_from_json.json"]

design -push
read_json [test_output_path "restore_from_json.json"]
write_sdc [test_output_path "restore_from_json_2.sdc"]
