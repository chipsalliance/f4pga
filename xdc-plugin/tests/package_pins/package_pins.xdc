#OBUF_6
set_property PACKAGE_PIN D10 [get_ports {led[0]}]
set_property DRIVE 12 [get_ports {led[0]}]
#OBUF_7
set_property PACKAGE_PIN A9 [get_ports {led[1]}]
set_property IN_TERM UNTUNED_SPLIT_40 [get_ports led[1]]
set_property SLEW FAST [get_ports led[1]]
set_property IOSTANDARD SSTL135 [get_ports led[1]]
#OBUF_OUT
set_property PACKAGE_PIN E3 [get_ports out_a]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports out_a]
set_property SLEW FAST [get_ports out_a]
set_property IOSTANDARD LVCMOS33 [get_ports out_a]
#bottom_inst.OBUF_10
set_property PACKAGE_PIN C2 [get_ports {out_b[0]}]
set_property SLEW SLOW [get_ports {out_b[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {out_b[0]}]
#bottom_inst.OBUF_11
set_property PACKAGE_PIN R2 [get_ports {out_b[1]}]
set_property DRIVE 4 [get_ports {out_b[1]}]
set_property SLEW FAST [get_ports {out_b[1]}]
set_property IOSTANDARD LVCMOS25 [get_ports {out_b[1]}]
#bottom_inst.OBUF_9
set_property PACKAGE_PIN M6 [get_ports {led[2]}]
set_property SLEW FAST [get_ports {led[2]}]
set_property IOSTANDARD DIFF_SSTL135 [get_ports {led[2]}]
#bottom_intermediate_inst.OBUF_8
set_property PACKAGE_PIN N4 [get_ports {led[3]}]
set_property DRIVE 16 [get_ports {led[3]}]
set_property IOSTANDARD SSTL135 [get_ports {led[3]}]
#OBUFTDS_2
set_property PACKAGE_PIN N2 [get_ports signal_p]
set_property PACKAGE_PIN N1 [get_ports signal_n]
set_property SLEW FAST [get_ports signal_p]
set_property IOSTANDARD DIFF_SSTL135 [get_ports signal_p]

