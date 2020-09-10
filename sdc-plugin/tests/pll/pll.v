module top(
	input clk,
	input cpu_reset,
	input data_in,
	output[4:0] data_out
);

wire [4:0] data_out;
wire builder_pll_fb;
wire fdce_0_out, fdce_1_out;
wire main_locked;

FDCE FDCE_0 (
	.D(data_in),
	.C(clk),
	.CE(1'b1),
	.CLR(1'b0),
	.Q(fdce_0_out)
);

FDCE FDCE_1 (
	.D(fdce_0_out),
	.C(clk),
	.CE(1'b1),
	.CLR(1'b0),
	.Q(data_out[0])
);

PLLE2_ADV #(
	.CLKFBOUT_MULT(4'd12),
	.CLKIN1_PERIOD(10.0),
	.CLKOUT0_DIVIDE(4'd12),
	.CLKOUT0_PHASE(90.0),
	.CLKOUT1_DIVIDE(2'd3),
	.CLKOUT1_PHASE(0.0),
	.DIVCLK_DIVIDE(1'd1),
	.REF_JITTER1(0.01),
	.STARTUP_WAIT("FALSE")
) PLLE2_ADV (
	.CLKFBIN(builder_pll_fb),
	.CLKIN1(clk),
	.RST(cpu_reset),
	.CLKFBOUT(builder_pll_fb),
	.CLKOUT0(main_clkout0),
	.CLKOUT1(main_clkout1),
	.LOCKED(main_locked)
);

FDCE FDCE_PLLx1 (
	.D(data_in),
	.C(main_clkout0),
	.CE(1'b1),
	.CLR(1'b0),
	.Q(data_out[1])
);

FDCE FDCE_PLLx4_0 (
	.D(data_in),
	.C(main_clkout1),
	.CE(1'b1),
	.CLR(1'b0),
	.Q(data_out[2])
);

FDCE FDCE_PLLx4_1 (
	.D(data_in),
	.C(main_clkout1),
	.CE(1'b1),
	.CLR(1'b0),
	.Q(data_out[3])
);

FDCE FDCE_PLLx4_2 (
	.D(data_in),
	.C(main_clkout1),
	.CE(1'b1),
	.CLR(1'b0),
	.Q(data_out[4])
);
endmodule
