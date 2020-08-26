create_clock -period 10 -waveform {0 5} clk_int_1
create_clock -period 10 -waveform {1 6} ibuf_proxy_out
create_clock -period 10 -waveform {2 7} \$auto\$clkbufmap.cc:247:execute\$1918
create_clock -period 10 -waveform {1 6} \$auto\$clkbufmap.cc:247:execute\$1920
create_clock -period 10 -waveform {3 8} middle_inst_1.clk_int
create_clock -period 10 -waveform {2 7} middle_inst_4.clk
