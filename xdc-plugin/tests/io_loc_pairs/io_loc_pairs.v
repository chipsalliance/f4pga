// Copyright (C) 2020-2021  The SymbiFlow Authors.
//
// Use of this source code is governed by a ISC-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/ISC
//
// SPDX-License-Identifier:ISC

module top (
    input clk,
    output [3:0] led,
    inout out_a,
    output [1:0] out_b,
    output signal_p,
    output signal_n,
    input rx_n,
    input rx_p,
    output tx_n,
    output tx_p,
    input ibufds_gte2_i,
    input ibufds_gte2_ib
);

  wire LD6, LD7, LD8, LD9;
  wire inter_wire, inter_wire_2;
  localparam BITS = 1;
  localparam LOG2DELAY = 25;

  reg [BITS+LOG2DELAY-1:0] counter = 0;

  always @(posedge clk) begin
    counter <= counter + 1;
  end
  assign led[1] = inter_wire;
  assign inter_wire = inter_wire_2;
  assign {LD9, LD8, LD7, LD6} = counter >> LOG2DELAY;

  OBUFTDS OBUFTDS_2 (
      .I (LD6),
      .O (signal_p),
      .OB(signal_n),
      .T (1'b1)
  );

  OBUF #(
      .IOSTANDARD("LVCMOS33"),
      .SLEW("SLOW")
  ) OBUF_6 (
      .I(LD6),
      .O(led[0])
  );

  OBUF #(
      .IOSTANDARD("LVCMOS33"),
      .SLEW("SLOW")
  ) OBUF_7 (
      .I(LD7),
      .O(inter_wire_2)
  );

  OBUF #(
      .IOSTANDARD("LVCMOS33"),
      .SLEW("SLOW")
  ) OBUF_OUT (
      .I(LD7),
      .O(out_a)
  );

  bottom bottom_inst (
      .I (LD8),
      .O (led[2]),
      .OB(out_b)
  );

  bottom_intermediate bottom_intermediate_inst (
      .I(LD9),
      .O(led[3])
  );

  GTPE2_CHANNEL GTPE2_CHANNEL (
      .GTPRXP(rx_p),
      .GTPRXN(rx_n),
      .GTPTXP(tx_p),
      .GTPTXN(tx_n)
  );

  (* keep *)
  IBUFDS_GTE2 IBUFDS_GTE2 (
      .I (ibufds_gte2_i),
      .IB(ibufds_gte2_ib)
  );
endmodule

module bottom_intermediate (
    input  I,
    output O
);

  wire bottom_intermediate_wire;
  assign O = bottom_intermediate_wire;

  OBUF #(
      .IOSTANDARD("LVCMOS33"),
      .SLEW("SLOW")
  ) OBUF_8 (
      .I(I),
      .O(bottom_intermediate_wire)
  );
endmodule

module bottom (
    input I,
    output [1:0] OB,
    output O
);

  OBUF #(
      .IOSTANDARD("LVCMOS33"),
      .SLEW("SLOW")
  ) OBUF_9 (
      .I(I),
      .O(O)
  );

  OBUF #(
      .IOSTANDARD("LVCMOS33"),
      .SLEW("SLOW")
  ) OBUF_10 (
      .I(I),
      .O(OB[0])
  );

  OBUF #(
      .IOSTANDARD("LVCMOS33"),
      .SLEW("SLOW")
  ) OBUF_11 (
      .I(I),
      .O(OB[1])
  );
endmodule
