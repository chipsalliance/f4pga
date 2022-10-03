create_clock -period 10 -waveform {0 5} clk_bufg
create_clock -period 10 -waveform {0 5} clk_ibuf
create_clock -period 10 -waveform {2.5 7.5} main_clkout0
create_clock -period 10 -waveform {2.5 7.5} main_clkout0_bufg
create_clock -period 2.5 -waveform {0 1.25} main_clkout1
create_clock -period 2.5 -waveform {0 1.25} main_clkout1_bufg
create_clock -period 5 -waveform {1.25 3.75} main_clkout2
create_clock -period 5 -waveform {1.25 3.75} main_clkout2_bufg
