#set_property LOC R2 [get_ports led]
#OBUF_6
set_property DRIVE 12 [get_ports {led[0]}]
#OBUF_7
set_property -dict { IN_TERM UNTUNED_SPLIT_40 SLEW FAST IOSTANDARD SSTL135 } [get_ports {led[1]}]
#OBUF_OUT
set_property -dict {IN_TERM UNTUNED_SPLIT_50 SLEW FAST IOSTANDARD LVCMOS33} [get_ports {out_a}]
#bottom_inst.OBUF_10
set_property -dict { SLEW SLOW IOSTANDARD LVCMOS18 } [get_ports {out_b[0]}]
#bottom_inst.OBUF_11
set_property -dict { DRIVE 4 SLEW FAST IOSTANDARD LVCMOS25 } [get_ports {out_b[1]}]
#bottom_inst.OBUF_9
set_property -dict { SLEW FAST IOSTANDARD DIFF_SSTL135 } [get_ports {led[2]}]
#bottom_intermediate_inst.OBUF_8
set_property -dict { DRIVE 16 IOSTANDARD SSTL135 } [get_ports {led[3]}]
#set_property INTERNAL_VREF 0.600 [get_iobanks 14]
#set_property INTERNAL_VREF 0.675 [get_iobanks 15]
#set_property INTERNAL_VREF 0.750 [get_iobanks 16]
#set_property INTERNAL_VREF 0.900 [get_iobanks 34]
#set_property INTERNAL_VREF 0.900 [get_iobanks 35]
