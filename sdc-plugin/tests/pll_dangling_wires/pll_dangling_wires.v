// Copyright (C) 2020-2021  The SymbiFlow Authors.
//
// Use of this source code is governed by a ISC-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/ISC
//
// SPDX-License-Identifier:ISC

module top (
    input  clk,
    input  cpu_reset,
    input  data_in,
    output data_out
);

  wire data_out;
  wire builder_pll_fb;
  wire main_locked;

  PLLE2_ADV #(
      .CLKFBOUT_MULT(4'd12),
      .CLKIN1_PERIOD(10.0),
      .CLKOUT0_DIVIDE(4'd12),
      .CLKOUT0_PHASE(0.0),
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
      .CLKOUT2(main_clkout2),
      .CLKOUT3(main_clkout3),
      .CLKOUT4(main_clkout4),
      .LOCKED(main_locked)
  );

  FDCE FDCE_PLLx1_PH0 (
      .D  (data_in),
      .C  (main_clkout0),
      .CE (1'b1),
      .CLR(1'b0),
      .Q  (data_out)
  );

endmodule
