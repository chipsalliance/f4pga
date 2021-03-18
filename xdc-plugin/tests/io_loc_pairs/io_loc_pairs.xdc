# OBUF_6
set_property LOC D10 [get_ports {led[0]}]
set_property DRIVE 12 [get_ports {led[0]}]

# OBUF_7
set_property LOC A9 [get_ports {led[1]}]
set_property IN_TERM UNTUNED_SPLIT_40 [get_ports led[1]]
set_property SLEW FAST [get_ports led[1]]
set_property IOSTANDARD SSTL135 [get_ports led[1]]

# OBUF_OUT
set_property LOC E3 [get_ports out_a]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports out_a]
set_property SLEW FAST [get_ports out_a]
set_property IOSTANDARD LVCMOS33 [get_ports out_a]

# bottom_inst.OBUF_10
set_property LOC C2 [get_ports {out_b[0]}]
set_property SLEW SLOW [get_ports {out_b[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {out_b[0]}]

# bottom_inst.OBUF_11
set_property LOC R2 [get_ports {out_b[1]}]
set_property DRIVE 4 [get_ports {out_b[1]}]
set_property SLEW FAST [get_ports {out_b[1]}]
set_property IOSTANDARD LVCMOS25 [get_ports {out_b[1]}]

# bottom_inst.OBUF_9
set_property LOC M6 [get_ports {led[2]}]
set_property SLEW FAST [get_ports {led[2]}]
set_property IOSTANDARD DIFF_SSTL135 [get_ports {led[2]}]

# bottom_intermediate_inst.OBUF_8
set_property LOC N4 [get_ports {led[3]}]
set_property DRIVE 16 [get_ports {led[3]}]
set_property IOSTANDARD SSTL135 [get_ports {led[3]}]

# OBUFTDS_2
set_property LOC N2 [get_ports signal_p]
set_property LOC N1 [get_ports signal_n]
set_property SLEW FAST [get_ports signal_p]
set_property IOSTANDARD DIFF_SSTL135 [get_ports signal_p]

# GTPE2_CHANNEL
set_property LOC G1 [get_ports {rx_p}]
set_property LOC G2 [get_ports {rx_n}]
set_property LOC G3 [get_ports {tx_p}]
set_property LOC G4 [get_ports {tx_n}]

# IBUFDS_GTE2
set_property LOC G5 [get_ports {ibufds_gte2_i}]
set_property LOC G6 [get_ports {ibufds_gte2_ib}]
