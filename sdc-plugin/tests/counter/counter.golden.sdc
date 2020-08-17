create_clock -period 10 -name clk_int_1 -waveform {0 5} clk_int_1 clk_int_2 ibuf_out middle_inst_1.clk middle_inst_1.clk_int middle_inst_2.clk middle_inst_2.clk_int middle_inst_3.clk middle_inst_3.clk_int
create_clock -period 10 -name clk -waveform {0 5} clk clk2
create_clock -period 10 -waveform {1 6} ibuf_proxy_out
create_clock -period 10 -waveform {2 7} $auto$clkbufmap.cc:247:execute$1918
create_clock -period 10 -waveform {1 6} $auto$clkbufmap.cc:247:execute$1920
