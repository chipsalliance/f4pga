// Copyright (C) 2020-2021  The SymbiFlow Authors.
//
// Use of this source code is governed by a ISC-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/ISC
//
// SPDX-License-Identifier:ISC

module top (
    input clk,
    input cpu_reset,
    input data_in,
    output [5:0] data_out
);

  wire [5:0] data_out;
  wire builder_pll_fb;
  wire fdce_0_out, fdce_1_out;
  wire main_locked;

  FDCE FDCE_0 (
      .D  (data_in),
      .C  (clk),
      .CE (1'b1),
      .CLR(1'b0),
      .Q  (fdce_0_out)
  );

  FDCE FDCE_1 (
      .D  (fdce_0_out),
      .C  (clk),
      .CE (1'b1),
      .CLR(1'b0),
      .Q  (data_out[0])
  );

  PLLE2_ADV #(
      .CLKFBOUT_MULT(4'd12),
      .CLKFBOUT_PHASE(90.0),
      .CLKIN1_PERIOD(10.0),
      .CLKOUT0_DIVIDE(4'd12),
      .CLKOUT0_PHASE(90.0),
      .CLKOUT1_DIVIDE(3'd6),
      .CLKOUT1_PHASE(0.0),
      .CLKOUT2_DIVIDE(2'd3),
      .CLKOUT2_PHASE(90.0),
      .REF_JITTER1(0.01),
      .STARTUP_WAIT("FALSE")
  ) PLLE2_ADV (
      .CLKFBIN(builder_pll_fb),
      .CLKIN1(clk),
      .RST(cpu_reset),
      .CLKFBOUT(builder_pll_fb),
      .CLKOUT0(main_clkout_x1),
      .CLKOUT1(main_clkout_x2),
      .CLKOUT2(main_clkout_x4),
      .LOCKED(main_locked)
  );

  FDCE FDCE_PLLx1_PH90 (
      .D  (data_in),
      .C  (main_clkout_x1),
      .CE (1'b1),
      .CLR(1'b0),
      .Q  (data_out[1])
  );

  FDCE FDCE_PLLx4_PH0_0 (
      .D  (data_in),
      .C  (main_clkout_x2),
      .CE (1'b1),
      .CLR(1'b0),
      .Q  (data_out[2])
  );

  FDCE FDCE_PLLx4_PH0_1 (
      .D  (data_in),
      .C  (main_clkout_x2),
      .CE (1'b1),
      .CLR(1'b0),
      .Q  (data_out[3])
  );

  FDCE FDCE_PLLx4_PH0_2 (
      .D  (data_in),
      .C  (main_clkout_x2),
      .CE (1'b1),
      .CLR(1'b0),
      .Q  (data_out[4])
  );

  FDCE FDCE_PLLx2_PH90_0 (
      .D  (data_in),
      .C  (main_clkout_x4),
      .CE (1'b1),
      .CLR(1'b0),
      .Q  (data_out[5])
  );
endmodule
