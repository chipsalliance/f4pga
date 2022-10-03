// Copyright 2020-2022 F4PGA Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0

module top (
    input clk,
    output [3:0] led,
    inout out_a,
    output [1:0] out_b,
    output signal_p,
    output signal_n
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

