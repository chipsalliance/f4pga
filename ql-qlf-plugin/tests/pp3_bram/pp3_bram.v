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

module my_ram (
    CLK,
    WADR,
    WDAT,
    WEN,
    RADR,
    RDAT,
    REN
);

  parameter DBITS = 36;
  parameter ABITS = 9;

  input wire CLK;

  input wire [ABITS-1:0] WADR;
  input wire [DBITS-1:0] WDAT;
  input wire WEN;

  input wire [ABITS-1:0] RADR;
  output reg [DBITS-1:0] RDAT;
  input wire REN;

  localparam SIZE = 1 << ABITS;
  reg [DBITS-1:0] mem[0:SIZE-1];

  always @(posedge CLK) begin
    if (WEN) mem[WADR] <= WDAT;
  end

  always @(posedge CLK) begin
    RDAT <= mem[RADR];
  end

endmodule

// ============================================================================

module top_bram_9_16 (
    CLK,
    WADR,
    WDAT,
    WEN,
    RADR,
    RDAT
);

  input wire CLK;

  input wire [8 : 0] WADR;
  input wire [15:0] WDAT;
  input wire WEN;

  input wire [8 : 0] RADR;
  output wire [15:0] RDAT;

  my_ram #(
      .DBITS(16),
      .ABITS(9)
  ) the_ram (
      .CLK (CLK),
      .WADR(WADR),
      .WDAT(WDAT),
      .WEN (WEN),
      .RADR(RADR),
      .RDAT(RDAT),
      .REN (1'b0)
  );

endmodule

module top_bram_9_32 (
    CLK,
    WADR,
    WDAT,
    WEN,
    RADR,
    RDAT
);

  input wire CLK;

  input wire [8 : 0] WADR;
  input wire [31:0] WDAT;
  input wire WEN;

  input wire [8 : 0] RADR;
  output wire [31:0] RDAT;

  my_ram #(
      .DBITS(32),
      .ABITS(9)
  ) the_ram (
      .CLK (CLK),
      .WADR(WADR),
      .WDAT(WDAT),
      .WEN (WEN),
      .RADR(RADR),
      .RDAT(RDAT),
      .REN (1'b0)
  );

endmodule

module top_bram_10_16 (
    CLK,
    WADR,
    WDAT,
    WEN,
    RADR,
    RDAT
);

  input wire CLK;

  input wire [9 : 0] WADR;
  input wire [15:0] WDAT;
  input wire WEN;

  input wire [9 : 0] RADR;
  output wire [15:0] RDAT;

  my_ram #(
      .DBITS(16),
      .ABITS(10)
  ) the_ram (
      .CLK (CLK),
      .WADR(WADR),
      .WDAT(WDAT),
      .WEN (WEN),
      .RADR(RADR),
      .RDAT(RDAT),
      .REN (1'b0)
  );

endmodule

module top_bram_init (
    CLK,
    WADR,
    WDAT,
    WEN,
    RADR,
    RDAT
);

  input wire CLK;

  input wire [9 : 0] WADR;
  input wire [17:0] WDAT;
  input wire WEN;

  input wire [9 : 0] RADR;
  output wire [17:0] RDAT;

  RAM_8K_BLK #(
      .INIT_FILE     ("init.txt"),
      .addr_int      (9),
      .data_depth_int(1 << 9),
      .data_width_int(16)
  ) the_ram (
      .WClk   (CLK),
      .RClk   (CLK),
      .WClk_En(1'b1),
      .RClk_En(1'b1),
      .WA     (WADR),
      .WD     (WDAT),
      .WEN    (WEN),
      .RA     (RADR),
      .RD     (RDAT)
  );

endmodule

