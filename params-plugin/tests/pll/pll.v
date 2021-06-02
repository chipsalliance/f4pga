// Copyright (C) 2020-2021  The SymbiFlow Authors.
//
// Use of this source code is governed by a ISC-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/ISC
//
// SPDX-License-Identifier:ISC

module top (
    (* dont_touch = "true" *) input clk100,
    input cpu_reset,
    output [2:0] led
);

  wire [2:0] led;
  wire builder_pll_fb;

  assign led[0] = main_locked;
  assign led[1] = main_clkout0;
  assign led[2] = main_clkout1;

  PLLE2_ADV #(
      .CLKFBOUT_MULT(4'd12),
      .CLKIN1_PERIOD(10.0),
      .CLKOUT0_DIVIDE(5'd20),
      .CLKOUT0_PHASE(1'd0),
      .CLKOUT1_DIVIDE(3'd5),
      .CLKOUT1_PHASE(1'd0),
      .CLKOUT2_DIVIDE(3'd5),
      .CLKOUT2_PHASE(7'd70),
      .CLKOUT3_DIVIDE(3'd6),
      .CLKOUT3_PHASE(1'd0),
      .DIVCLK_DIVIDE(1'd1),
      .REF_JITTER1(0.01),
      .STARTUP_WAIT("FALSE")
  ) PLLE2_ADV_0 (
      .CLKFBIN(builder_pll_fb),
      .CLKIN1(clk100),
      .RST(cpu_reset),
      .CLKFBOUT(builder_pll_fb),
      .CLKOUT0(main_clkout0),
      .CLKOUT1(main_clkout1),
      .LOCKED(main_locked)
  );
  PLLE2_ADV #(
      .CLKFBOUT_MULT(4'd12),
      .CLKIN1_PERIOD(10.0),
      .CLKOUT0_DIVIDE(5'd20),
      .CLKOUT0_PHASE(1'd0),
      .CLKOUT1_DIVIDE(3'd5),
      .CLKOUT1_PHASE(1'd0),
      .CLKOUT2_DIVIDE(3'd5),
      .CLKOUT2_PHASE(7'd90),
      .CLKOUT3_DIVIDE(3'd6),
      .CLKOUT3_PHASE(1'd0),
      .DIVCLK_DIVIDE(1'd1),
      .REF_JITTER1(0.01),
      .STARTUP_WAIT("FALSE")
  ) PLLE2_ADV (
      .CLKFBIN(builder_pll_fb),
      .CLKIN1(clk100),
      .RST(cpu_reset),
      .CLKFBOUT(builder_pll_fb),
      .CLKOUT0(main_clkout0),
      .CLKOUT1(main_clkout1),
      .LOCKED(main_locked)
  );

endmodule
