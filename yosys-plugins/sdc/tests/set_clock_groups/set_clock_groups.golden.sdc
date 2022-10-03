create_clock_groups -group clk1 clk2 
create_clock_groups -group clk3 clk4 -group clk11 clk12 -group clk13 clk14 -asynchronous
create_clock_groups -group clk7 clk8 -group clk9 clk10 -physically_exclusive
create_clock_groups -group clk5 clk6 -logically_exclusive
