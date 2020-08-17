create_clock -period 10 -waveform {0 5} clk
create_clock -period 10 -waveform {0 5} $auto$clkbufmap.cc:247:execute$1829
create_clock -period 2.5 -waveform {0 1.25} $auto$clkbufmap.cc:247:execute$1831
create_clock -period 10 -waveform {1 6} $auto$clkbufmap.cc:247:execute$1827
create_clock -period 10 -waveform {1 6} main_clkout0
create_clock -period 2.5 -waveform {1 2.25} main_clkout1
create_clock -period 10 -waveform {2 7} $techmap1716\FDCE_0.C
