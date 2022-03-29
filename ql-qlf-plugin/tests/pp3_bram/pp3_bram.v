// Copyright (C) 2019-2022 The SymbiFlow Authors
//
// Use of this source code is governed by a ISC-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/ISC
//
// SPDX-License-Identifier: ISC

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

