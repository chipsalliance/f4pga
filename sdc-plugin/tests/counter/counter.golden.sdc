create_clock -period 10 -waveform {0 5} \$auto\$clkbufmap.cc:262:execute\$1801
create_clock -period 10 -waveform {0 5} \$auto\$clkbufmap.cc:262:execute\$1803
create_clock -period 10 -waveform {0 5} clk_int_1
create_clock -period 10 -waveform {0 5} ibuf_proxy_out
create_clock -period 10 -waveform {0 5} middle_inst_1.clk_int
create_clock -period 10 -waveform {0 5} middle_inst_4.clk
