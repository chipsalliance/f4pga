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
    (* CLOCK_SIGNAL = "yes", PERIOD = "10", WAVEFORM = "bad value" *)
    input clk,
    input clk2,
    input [1:0] in,
    output [5:0] out
);

  reg [1:0] cnt = 0;
  wire clk_int_1, clk_int_2;
  IBUF ibuf_proxy (
      .I(clk),
      .O(ibuf_proxy_out)
  );
  IBUF ibuf_inst (
      .I(ibuf_proxy_out),
      .O(ibuf_out)
  );
  assign clk_int_1 = ibuf_out;
  assign clk_int_2 = clk_int_1;

  always @(posedge clk_int_2) begin
    cnt <= cnt + 1;
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

  assign out[1:0] = {cnt[0], in[0]};
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
