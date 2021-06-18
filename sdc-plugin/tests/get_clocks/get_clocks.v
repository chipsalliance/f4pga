// Copyright (C) 2020-2021  The SymbiFlow Authors.
//
// Use of this source code is governed by a ISC-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/ISC
//
// SPDX-License-Identifier:ISC

module top (
    input clk,
    input clk2,
    input [1:0] in,
    output [5:0] out
);

  reg [1:0] cnt = 0;
  reg [1:0] cnt2 = 0;
  wire clk_int_1, clk_int_2;
  IBUF ibuf_inst (
      .I(clk),
      .O(ibuf_out)
  );
  assign clk_int_1 = ibuf_out;
  assign clk_int_2 = clk_int_1;

  PLLE2_ADV #(
      .CLKFBOUT_MULT(4'd12),
      .CLKIN1_PERIOD(10.0),
      .CLKOUT0_DIVIDE(4'd12),
      .CLKOUT0_PHASE(90.0),
      .DIVCLK_DIVIDE(1'd1),
      .REF_JITTER1(0.01),
      .STARTUP_WAIT("FALSE")
  ) PLLE2_ADV (
      .CLKFBIN(builder_pll_fb),
      .CLKIN1(clk),
      .RST(cpu_reset),
      .CLKFBOUT(builder_pll_fb),
      .CLKOUT0(main_clkout0),
  );

  always @(posedge clk_int_2) begin
    cnt <= cnt + 1;
  end

  always @(posedge main_clkout0) begin
    cnt2 <= cnt2 + 1;
  end

  middle middle_inst_1 (
      .clk(ibuf_out),
      .out(out[2])
  );
  middle middle_inst_2 (
      .clk(clk_int_1),
      .out(out[3])
  );
  middle middle_inst_3 (
      .clk(clk_int_2),
      .out(out[4])
  );
  middle middle_inst_4 (
      .clk(clk2),
      .out(out[5])
  );

  assign out[2:0] = {cnt2[0], cnt[0], in[0]};
endmodule

module middle (
    input  clk,
    output out
);

  reg [1:0] cnt = 0;
  wire clk_int;
  assign clk_int = clk;
  always @(posedge clk_int) begin
    cnt <= cnt + 1;
  end

  assign out = cnt[0];
endmodule
