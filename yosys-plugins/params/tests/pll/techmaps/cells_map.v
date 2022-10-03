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

// ============================================================================
// CMT

`define PLL_FRAC_PRECISION 10
`define PLL_FIXED_WIDTH 32

// Rounds a fixed point number to a given precision
function [`PLL_FIXED_WIDTH:1] pll_round_frac(input [`PLL_FIXED_WIDTH:1] decimal,
                                             input [`PLL_FIXED_WIDTH:1] precision);

  if (decimal[(`PLL_FRAC_PRECISION-precision)] == 1'b1) begin
    pll_round_frac = decimal + (1'b1 << (`PLL_FRAC_PRECISION - precision));
  end else begin
    pll_round_frac = decimal;
  end

endfunction

// Computes content of the PLLs divider registers
function [13:0] pll_divider_regs(input [7:0] divide,  // Max divide is 128
                                 input [31:0] duty_cycle   // Duty cycle is multiplied by 100,000
);

  reg [`PLL_FIXED_WIDTH:1] duty_cycle_fix;
  reg [`PLL_FIXED_WIDTH:1] duty_cycle_min;
  reg [`PLL_FIXED_WIDTH:1] duty_cycle_max;

  reg [               6:0] high_time;
  reg [               6:0] low_time;
  reg                      w_edge;
  reg                      no_count;

  reg [`PLL_FIXED_WIDTH:1] temp;

  if (divide >= 64) begin
    duty_cycle_min = ((divide - 64) * 100_000) / divide;
    duty_cycle_max = (645 / divide) * 100_00;
    if (duty_cycle > duty_cycle_max) duty_cycle = duty_cycle_max;
    if (duty_cycle < duty_cycle_min) duty_cycle = duty_cycle_min;
  end

  duty_cycle_fix = (duty_cycle << `PLL_FRAC_PRECISION) / 100_000;

  if (divide == 7'h01) begin
    high_time = 7'h01;
    w_edge    = 1'b0;
    low_time  = 7'h01;
    no_count  = 1'b1;

  end else begin
    temp = pll_round_frac(duty_cycle_fix*divide, 1);

    high_time = temp[`PLL_FRAC_PRECISION+7:`PLL_FRAC_PRECISION+1];
    w_edge    = temp[`PLL_FRAC_PRECISION];

    if (high_time == 7'h00) begin
      high_time = 7'h01;
      w_edge    = 1'b0;
    end

    if (high_time == divide) begin
      high_time = divide - 1;
      w_edge    = 1'b1;
    end

    low_time = divide - high_time;
    no_count = 1'b0;
  end

  pll_divider_regs = {w_edge, no_count, high_time[5:0], low_time[5:0]};
endfunction

// Computes the PLLs phase shift registers
function [10:0] pll_phase_regs(input [7:0] divide, input signed [31:0] phase);

  reg [`PLL_FIXED_WIDTH:1] phase_in_cycles;
  reg [`PLL_FIXED_WIDTH:1] phase_fixed;
  reg [1:0] mx;
  reg [5:0] delay_time;
  reg [2:0] phase_mux;

  reg [`PLL_FIXED_WIDTH:1] temp;

  if (phase < 0) begin
    phase_fixed = ((phase + 360000) << `PLL_FRAC_PRECISION) / 1000;
  end else begin
    phase_fixed = (phase << `PLL_FRAC_PRECISION) / 1000;
  end

  phase_in_cycles = (phase_fixed * divide) / 360;
  temp            = pll_round_frac(phase_in_cycles, 3);

  mx              = 2'b00;
  phase_mux       = temp[`PLL_FRAC_PRECISION:`PLL_FRAC_PRECISION-2];
  delay_time      = temp[`PLL_FRAC_PRECISION+6:`PLL_FRAC_PRECISION+1];

  pll_phase_regs  = {mx, phase_mux, delay_time};
endfunction


// Given PLL/MMCM divide, duty_cycle and phase calculates content of the
// CLKREG1 and CLKREG2.
function [37:0] pll_clkregs(input [7:0] divide,  // Max divide is 128
                            input [31:0] duty_cycle,  // Multiplied by 100,000
                            input signed [31:0] phase       // Phase is given in degrees (-360,000 to 360,000)
);

  reg [13:0] pll_div;  // EDGE, NO_COUNT, HIGH_TIME[5:0], LOW_TIME[5:0]
  reg [10:0] pll_phase;  // MX, PHASE_MUX[2:0], DELAY_TIME[5:0]

  pll_div = pll_divider_regs(divide, duty_cycle);
  pll_phase = pll_phase_regs(divide, phase);

  pll_clkregs = {
    // CLKREG2: RESERVED[6:0], MX[1:0], EDGE, NO_COUNT, DELAY_TIME[5:0]
    6'h00,
    pll_phase[10:9],
    pll_div[13:12],
    pll_phase[5:0],
    // CLKREG1: PHASE_MUX[3:0], RESERVED, HIGH_TIME[5:0], LOW_TIME[5:0]
    pll_phase[8:6],
    1'b0,
    pll_div[11:0]
  };

endfunction

// This function takes the divide value and outputs the necessary lock values
function [39:0] pll_lktable_lookup(input [6:0] divide // Max divide is 64
);

  reg [2559:0] lookup;

  lookup = {
    // This table is composed of:
    // LockRefDly_LockFBDly_LockCnt_LockSatHigh_UnlockCnt
    40'b00110_00110_1111101000_1111101001_0000000001,
    40'b00110_00110_1111101000_1111101001_0000000001,
    40'b01000_01000_1111101000_1111101001_0000000001,
    40'b01011_01011_1111101000_1111101001_0000000001,
    40'b01110_01110_1111101000_1111101001_0000000001,
    40'b10001_10001_1111101000_1111101001_0000000001,
    40'b10011_10011_1111101000_1111101001_0000000001,
    40'b10110_10110_1111101000_1111101001_0000000001,
    40'b11001_11001_1111101000_1111101001_0000000001,
    40'b11100_11100_1111101000_1111101001_0000000001,
    40'b11111_11111_1110000100_1111101001_0000000001,
    40'b11111_11111_1100111001_1111101001_0000000001,
    40'b11111_11111_1011101110_1111101001_0000000001,
    40'b11111_11111_1010111100_1111101001_0000000001,
    40'b11111_11111_1010001010_1111101001_0000000001,
    40'b11111_11111_1001110001_1111101001_0000000001,
    40'b11111_11111_1000111111_1111101001_0000000001,
    40'b11111_11111_1000100110_1111101001_0000000001,
    40'b11111_11111_1000001101_1111101001_0000000001,
    40'b11111_11111_0111110100_1111101001_0000000001,
    40'b11111_11111_0111011011_1111101001_0000000001,
    40'b11111_11111_0111000010_1111101001_0000000001,
    40'b11111_11111_0110101001_1111101001_0000000001,
    40'b11111_11111_0110010000_1111101001_0000000001,
    40'b11111_11111_0110010000_1111101001_0000000001,
    40'b11111_11111_0101110111_1111101001_0000000001,
    40'b11111_11111_0101011110_1111101001_0000000001,
    40'b11111_11111_0101011110_1111101001_0000000001,
    40'b11111_11111_0101000101_1111101001_0000000001,
    40'b11111_11111_0101000101_1111101001_0000000001,
    40'b11111_11111_0100101100_1111101001_0000000001,
    40'b11111_11111_0100101100_1111101001_0000000001,
    40'b11111_11111_0100101100_1111101001_0000000001,
    40'b11111_11111_0100010011_1111101001_0000000001,
    40'b11111_11111_0100010011_1111101001_0000000001,
    40'b11111_11111_0100010011_1111101001_0000000001,
    40'b11111_11111_0011111010_1111101001_0000000001,
    40'b11111_11111_0011111010_1111101001_0000000001,
    40'b11111_11111_0011111010_1111101001_0000000001,
    40'b11111_11111_0011111010_1111101001_0000000001,
    40'b11111_11111_0011111010_1111101001_0000000001,
    40'b11111_11111_0011111010_1111101001_0000000001,
    40'b11111_11111_0011111010_1111101001_0000000001,
    40'b11111_11111_0011111010_1111101001_0000000001,
    40'b11111_11111_0011111010_1111101001_0000000001,
    40'b11111_11111_0011111010_1111101001_0000000001,
    40'b11111_11111_0011111010_1111101001_0000000001,
    40'b11111_11111_0011111010_1111101001_0000000001,
    40'b11111_11111_0011111010_1111101001_0000000001,
    40'b11111_11111_0011111010_1111101001_0000000001,
    40'b11111_11111_0011111010_1111101001_0000000001,
    40'b11111_11111_0011111010_1111101001_0000000001,
    40'b11111_11111_0011111010_1111101001_0000000001,
    40'b11111_11111_0011111010_1111101001_0000000001,
    40'b11111_11111_0011111010_1111101001_0000000001,
    40'b11111_11111_0011111010_1111101001_0000000001,
    40'b11111_11111_0011111010_1111101001_0000000001,
    40'b11111_11111_0011111010_1111101001_0000000001,
    40'b11111_11111_0011111010_1111101001_0000000001,
    40'b11111_11111_0011111010_1111101001_0000000001,
    40'b11111_11111_0011111010_1111101001_0000000001,
    40'b11111_11111_0011111010_1111101001_0000000001,
    40'b11111_11111_0011111010_1111101001_0000000001,
    40'b11111_11111_0011111010_1111101001_0000000001
  };

  pll_lktable_lookup = lookup[((64-divide)*40)+:40];
endfunction

// This function takes the divide value and the bandwidth setting of the PLL
// and outputs the digital filter settings necessary.
function [9:0] pll_table_lookup(input [6:0] divide,  // Max divide is 64
                                input [8*9:0] BANDWIDTH);

  reg [639:0] lookup_low;
  reg [639:0] lookup_high;
  reg [639:0] lookup_optimized;

  reg [  9:0] lookup_entry;

  lookup_low = {
    // CP_RES_LFHF
    10'b0010_1111_00,
    10'b0010_1111_00,
    10'b0010_0111_00,
    10'b0010_1101_00,
    10'b0010_0101_00,
    10'b0010_0101_00,
    10'b0010_1001_00,
    10'b0010_1110_00,
    10'b0010_1110_00,
    10'b0010_0001_00,
    10'b0010_0001_00,
    10'b0010_0110_00,
    10'b0010_0110_00,
    10'b0010_0110_00,
    10'b0010_0110_00,
    10'b0010_1010_00,
    10'b0010_1010_00,
    10'b0010_1010_00,
    10'b0010_1010_00,
    10'b0010_1100_00,
    10'b0010_1100_00,
    10'b0010_1100_00,
    10'b0010_1100_00,
    10'b0010_1100_00,
    10'b0010_1100_00,
    10'b0010_1100_00,
    10'b0010_1100_00,
    10'b0010_1100_00,
    10'b0010_1100_00,
    10'b0010_1100_00,
    10'b0010_0010_00,
    10'b0010_0010_00,
    10'b0010_0010_00,
    10'b0010_0010_00,
    10'b0010_0010_00,
    10'b0010_0010_00,
    10'b0010_0010_00,
    10'b0010_0010_00,
    10'b0010_0010_00,
    10'b0010_0010_00,
    10'b0011_1100_00,
    10'b0011_1100_00,
    10'b0011_1100_00,
    10'b0011_1100_00,
    10'b0011_1100_00,
    10'b0011_1100_00,
    10'b0011_1100_00,
    10'b0010_0100_00,
    10'b0010_0100_00,
    10'b0010_0100_00,
    10'b0010_0100_00,
    10'b0010_0100_00,
    10'b0010_0100_00,
    10'b0010_0100_00,
    10'b0010_0100_00,
    10'b0010_0100_00,
    10'b0010_0100_00,
    10'b0010_0100_00,
    10'b0010_0100_00,
    10'b0010_0100_00,
    10'b0010_0100_00,
    10'b0010_0100_00,
    10'b0010_0100_00,
    10'b0010_0100_00
  };

  lookup_high = {
    // CP_RES_LFHF
    10'b0011_0111_00,
    10'b0011_0111_00,
    10'b0101_1111_00,
    10'b0111_1111_00,
    10'b0111_1011_00,
    10'b1101_0111_00,
    10'b1110_1011_00,
    10'b1110_1101_00,
    10'b1111_1101_00,
    10'b1111_0111_00,
    10'b1111_1011_00,
    10'b1111_1101_00,
    10'b1111_0011_00,
    10'b1110_0101_00,
    10'b1111_0101_00,
    10'b1111_0101_00,
    10'b1111_0101_00,
    10'b1111_0101_00,
    10'b0111_0110_00,
    10'b0111_0110_00,
    10'b0111_0110_00,
    10'b0111_0110_00,
    10'b0101_1100_00,
    10'b0101_1100_00,
    10'b0101_1100_00,
    10'b1100_0001_00,
    10'b1100_0001_00,
    10'b1100_0001_00,
    10'b1100_0001_00,
    10'b1100_0001_00,
    10'b1100_0001_00,
    10'b1100_0001_00,
    10'b1100_0001_00,
    10'b0100_0010_00,
    10'b0100_0010_00,
    10'b0100_0010_00,
    10'b0010_1000_00,
    10'b0010_1000_00,
    10'b0010_1000_00,
    10'b0011_0100_00,
    10'b0010_1000_00,
    10'b0010_1000_00,
    10'b0010_1000_00,
    10'b0010_1000_00,
    10'b0010_1000_00,
    10'b0010_1000_00,
    10'b0010_1000_00,
    10'b0010_1000_00,
    10'b0010_1000_00,
    10'b0010_1000_00,
    10'b0010_1000_00,
    10'b0010_1000_00,
    10'b0010_1000_00,
    10'b0100_1100_00,
    10'b0100_1100_00,
    10'b0100_1100_00,
    10'b0100_1100_00,
    10'b0100_1100_00,
    10'b0100_1100_00,
    10'b0100_1100_00,
    10'b0010_0100_00,
    10'b0010_0100_00,
    10'b0010_0100_00,
    10'b0010_0100_00
  };

  lookup_optimized = {
    // CP_RES_LFHF
    10'b0011_0111_00,
    10'b0011_0111_00,
    10'b0101_1111_00,
    10'b0111_1111_00,
    10'b0111_1011_00,
    10'b1101_0111_00,
    10'b1110_1011_00,
    10'b1110_1101_00,
    10'b1111_1101_00,
    10'b1111_0111_00,
    10'b1111_1011_00,
    10'b1111_1101_00,
    10'b1111_0011_00,
    10'b1110_0101_00,
    10'b1111_0101_00,
    10'b1111_0101_00,
    10'b1111_0101_00,
    10'b1111_0101_00,
    10'b0111_0110_00,
    10'b0111_0110_00,
    10'b0111_0110_00,
    10'b0111_0110_00,
    10'b0101_1100_00,
    10'b0101_1100_00,
    10'b0101_1100_00,
    10'b1100_0001_00,
    10'b1100_0001_00,
    10'b1100_0001_00,
    10'b1100_0001_00,
    10'b1100_0001_00,
    10'b1100_0001_00,
    10'b1100_0001_00,
    10'b1100_0001_00,
    10'b0100_0010_00,
    10'b0100_0010_00,
    10'b0100_0010_00,
    10'b0010_1000_00,
    10'b0010_1000_00,
    10'b0010_1000_00,
    10'b0011_0100_00,
    10'b0010_1000_00,
    10'b0010_1000_00,
    10'b0010_1000_00,
    10'b0010_1000_00,
    10'b0010_1000_00,
    10'b0010_1000_00,
    10'b0010_1000_00,
    10'b0010_1000_00,
    10'b0010_1000_00,
    10'b0010_1000_00,
    10'b0010_1000_00,
    10'b0010_1000_00,
    10'b0010_1000_00,
    10'b0100_1100_00,
    10'b0100_1100_00,
    10'b0100_1100_00,
    10'b0100_1100_00,
    10'b0100_1100_00,
    10'b0100_1100_00,
    10'b0100_1100_00,
    10'b0010_0100_00,
    10'b0010_0100_00,
    10'b0010_0100_00,
    10'b0010_0100_00
  };

  if (BANDWIDTH == "LOW") begin
    pll_table_lookup = lookup_low[((64-divide)*10)+:10];
  end else if (BANDWIDTH == "HIGH") begin
    pll_table_lookup = lookup_high[((64-divide)*10)+:10];
  end else if (BANDWIDTH == "OPTIMIZED") begin
    pll_table_lookup = lookup_optimized[((64-divide)*10)+:10];
  end

endfunction

// ............................................................................
// IMPORTANT NOTE: Due to lack of support for real type parameters in Yosys
// the PLL parameters that define duty cycles and phase shifts have to be
// provided as integers! The DUTY_CYCLE is expressed as % of high time times
// 1000 whereas the PHASE is expressed in degrees times 1000.

// PLLE2_ADV
module PLLE2_ADV (
    input CLKFBIN,
    input CLKIN1,
    input CLKIN2,
    input CLKINSEL,

    output CLKFBOUT,
    output CLKOUT0,
    output CLKOUT1,
    output CLKOUT2,
    output CLKOUT3,
    output CLKOUT4,
    output CLKOUT5,

    input  PWRDWN,
    input  RST,
    output LOCKED,

    input         DCLK,
    input         DEN,
    input         DWE,
    output        DRDY,
    input  [ 6:0] DADDR,
    input  [15:0] DI,
    output [15:0] DO
);

  parameter _TECHMAP_CONSTMSK_CLKINSEL_ = 0;
  parameter _TECHMAP_CONSTVAL_CLKINSEL_ = 0;

  parameter _TECHMAP_CONSTMSK_RST_ = 0;
  parameter _TECHMAP_CONSTVAL_RST_ = 0;
  parameter _TECHMAP_CONSTMSK_PWRDWN_ = 0;
  parameter _TECHMAP_CONSTVAL_PWRDWN_ = 0;

  parameter _TECHMAP_CONSTMSK_CLKFBOUT_ = 0;
  parameter _TECHMAP_CONSTVAL_CLKFBOUT_ = 0;
  parameter _TECHMAP_CONSTMSK_CLKOUT0_ = 0;
  parameter _TECHMAP_CONSTVAL_CLKOUT0_ = 0;
  parameter _TECHMAP_CONSTMSK_CLKOUT1_ = 0;
  parameter _TECHMAP_CONSTVAL_CLKOUT1_ = 0;
  parameter _TECHMAP_CONSTMSK_CLKOUT2_ = 0;
  parameter _TECHMAP_CONSTVAL_CLKOUT2_ = 0;
  parameter _TECHMAP_CONSTMSK_CLKOUT3_ = 0;
  parameter _TECHMAP_CONSTVAL_CLKOUT3_ = 0;
  parameter _TECHMAP_CONSTMSK_CLKOUT4_ = 0;
  parameter _TECHMAP_CONSTVAL_CLKOUT4_ = 0;
  parameter _TECHMAP_CONSTMSK_CLKOUT5_ = 0;
  parameter _TECHMAP_CONSTVAL_CLKOUT5_ = 0;

  parameter _TECHMAP_CONSTMSK_DCLK_ = 0;
  parameter _TECHMAP_CONSTVAL_DCLK_ = 0;
  parameter _TECHMAP_CONSTMSK_DEN_ = 0;
  parameter _TECHMAP_CONSTVAL_DEN_ = 0;
  parameter _TECHMAP_CONSTMSK_DWE_ = 0;
  parameter _TECHMAP_CONSTVAL_DWE_ = 0;

  parameter IS_CLKINSEL_INVERTED = 1'b0;
  parameter IS_RST_INVERTED = 1'b0;
  parameter IS_PWRDWN_INVERTED = 1'b0;

  parameter BANDWIDTH = "OPTIMIZED";
  parameter STARTUP_WAIT = "FALSE";
  parameter COMPENSATION = "ZHOLD";

  parameter CLKIN1_PERIOD = 0.0;
  parameter REF_JITTER1 = 0.01;
  parameter CLKIN2_PERIOD = 0.0;
  parameter REF_JITTER2 = 0.01;

  parameter [5:0] DIVCLK_DIVIDE = 1;

  parameter [5:0] CLKFBOUT_MULT = 1;
  parameter CLKFBOUT_PHASE = 0;

  parameter [6:0] CLKOUT0_DIVIDE = 1;
  parameter CLKOUT0_DUTY_CYCLE = 50000;
  parameter signed CLKOUT0_PHASE = 0;

  parameter [6:0] CLKOUT1_DIVIDE = 1;
  parameter CLKOUT1_DUTY_CYCLE = 50000;
  parameter signed CLKOUT1_PHASE = 0;

  parameter [6:0] CLKOUT2_DIVIDE = 1;
  parameter CLKOUT2_DUTY_CYCLE = 50000;
  parameter signed CLKOUT2_PHASE = 0;

  parameter [6:0] CLKOUT3_DIVIDE = 1;
  parameter CLKOUT3_DUTY_CYCLE = 50000;
  parameter signed CLKOUT3_PHASE = 0;

  parameter [6:0] CLKOUT4_DIVIDE = 1;
  parameter CLKOUT4_DUTY_CYCLE = 50000;
  parameter signed CLKOUT4_PHASE = 0;

  parameter [6:0] CLKOUT5_DIVIDE = 1;
  parameter CLKOUT5_DUTY_CYCLE = 50000;
  parameter signed CLKOUT5_PHASE = 0;

  // Compute PLL's registers content
  localparam CLKFBOUT_REGS = pll_clkregs(CLKFBOUT_MULT, 50000, CLKFBOUT_PHASE);
  localparam DIVCLK_REGS = pll_clkregs(DIVCLK_DIVIDE, 50000, 0);

  localparam CLKOUT0_REGS = pll_clkregs(CLKOUT0_DIVIDE, CLKOUT0_DUTY_CYCLE, CLKOUT0_PHASE);
  localparam CLKOUT1_REGS = pll_clkregs(CLKOUT1_DIVIDE, CLKOUT1_DUTY_CYCLE, CLKOUT1_PHASE);
  localparam CLKOUT2_REGS = pll_clkregs(CLKOUT2_DIVIDE, CLKOUT2_DUTY_CYCLE, CLKOUT2_PHASE);
  localparam CLKOUT3_REGS = pll_clkregs(CLKOUT3_DIVIDE, CLKOUT3_DUTY_CYCLE, CLKOUT3_PHASE);
  localparam CLKOUT4_REGS = pll_clkregs(CLKOUT4_DIVIDE, CLKOUT4_DUTY_CYCLE, CLKOUT4_PHASE);
  localparam CLKOUT5_REGS = pll_clkregs(CLKOUT5_DIVIDE, CLKOUT5_DUTY_CYCLE, CLKOUT5_PHASE);

  // Handle inputs that should have certain logic levels when left unconnected
  localparam INV_CLKINSEL = (_TECHMAP_CONSTMSK_CLKINSEL_ == 1) ? !_TECHMAP_CONSTVAL_CLKINSEL_ :
			     (_TECHMAP_CONSTVAL_CLKINSEL_ == 0) ? IS_CLKINSEL_INVERTED :
			     IS_CLKINSEL_INVERTED;
  generate
    if (_TECHMAP_CONSTMSK_CLKINSEL_ == 1) begin
      wire clkinsel = 1'b1;
    end else if (_TECHMAP_CONSTVAL_CLKINSEL_ == 0) begin
      wire clkinsel = 1'b1;
    end else begin
      wire clkinsel = CLKINSEL;
    end
  endgenerate

  localparam INV_PWRDWN = (_TECHMAP_CONSTMSK_PWRDWN_ == 1) ? !_TECHMAP_CONSTVAL_PWRDWN_ :
			  (_TECHMAP_CONSTVAL_PWRDWN_ == 0) ? ~IS_PWRDWN_INVERTED :
			  IS_PWRDWN_INVERTED;
  generate
    if (_TECHMAP_CONSTMSK_PWRDWN_ == 1) begin
      wire pwrdwn = 1'b1;
    end else if (_TECHMAP_CONSTVAL_PWRDWN_ == 0) begin
      wire pwrdwn = 1'b1;
    end else begin
      wire pwrdwn = PWRDWN;
    end
  endgenerate

  localparam INV_RST = (_TECHMAP_CONSTMSK_RST_ == 1) ? !_TECHMAP_CONSTVAL_PWRDWN_ :
		       (_TECHMAP_CONSTVAL_RST_ == 0) ? ~IS_RST_INVERTED : IS_RST_INVERTED;
  generate
    if (_TECHMAP_CONSTMSK_RST_ == 1) begin
      wire rst = 1'b1;
    end else if (_TECHMAP_CONSTVAL_RST_ == 0) begin
      wire rst = 1'b1;
    end else begin
      wire rst = RST;
    end
  endgenerate

  generate
    if (_TECHMAP_CONSTMSK_DCLK_ == 1) wire dclk = _TECHMAP_CONSTVAL_DCLK_;
    else if (_TECHMAP_CONSTVAL_DCLK_ == 0) wire dclk = 1'b0;
    else wire dclk = DCLK;
  endgenerate

  generate
    if (_TECHMAP_CONSTMSK_DEN_ == 1) wire den = _TECHMAP_CONSTVAL_DEN_;
    else if (_TECHMAP_CONSTVAL_DEN_ == 0) wire den = 1'b0;
    else wire den = DEN;
  endgenerate

  generate
    if (_TECHMAP_CONSTMSK_DWE_ == 1) wire dwe = _TECHMAP_CONSTVAL_DWE_;
    else if (_TECHMAP_CONSTVAL_DWE_ == 0) wire dwe = 1'b0;
    else wire dwe = DWE;
  endgenerate

  // The substituted cell
  PLLE2_ADV_VPR #(
      // Inverters
      .INV_CLKINSEL(INV_CLKINSEL),
      .ZINV_PWRDWN (INV_PWRDWN),
      .ZINV_RST    (INV_RST),

      // Straight mapped parameters
      .STARTUP_WAIT(STARTUP_WAIT == "TRUE"),

      // Lookup tables
      .LKTABLE(pll_lktable_lookup(CLKFBOUT_MULT)),
      .TABLE  (pll_table_lookup(CLKFBOUT_MULT, BANDWIDTH)),

      // FIXME: How to compute values the two below ?
      .FILTREG1_RESERVED(12'b0000_00001000),
      .LOCKREG3_RESERVED(1'b1),

      // Clock feedback settings
      .CLKFBOUT_CLKOUT1_HIGH_TIME (CLKFBOUT_REGS[11:6]),
      .CLKFBOUT_CLKOUT1_LOW_TIME  (CLKFBOUT_REGS[5:0]),
      .CLKFBOUT_CLKOUT1_PHASE_MUX (CLKFBOUT_REGS[15:13]),
      .CLKFBOUT_CLKOUT2_DELAY_TIME(CLKFBOUT_REGS[21:16]),
      .CLKFBOUT_CLKOUT2_EDGE      (CLKFBOUT_REGS[23]),
      .CLKFBOUT_CLKOUT2_NO_COUNT  (CLKFBOUT_REGS[22]),

      // Internal VCO divider settings
      .DIVCLK_DIVCLK_HIGH_TIME(DIVCLK_REGS[11:6]),
      .DIVCLK_DIVCLK_LOW_TIME (DIVCLK_REGS[5:0]),
      .DIVCLK_DIVCLK_NO_COUNT (DIVCLK_REGS[22]),
      .DIVCLK_DIVCLK_EDGE     (DIVCLK_REGS[23]),

      // CLKOUT0
      .CLKOUT0_CLKOUT1_HIGH_TIME (CLKOUT0_REGS[11:6]),
      .CLKOUT0_CLKOUT1_LOW_TIME  (CLKOUT0_REGS[5:0]),
      .CLKOUT0_CLKOUT1_PHASE_MUX (CLKOUT0_REGS[15:13]),
      .CLKOUT0_CLKOUT2_DELAY_TIME(CLKOUT0_REGS[21:16]),
      .CLKOUT0_CLKOUT2_EDGE      (CLKOUT0_REGS[23]),
      .CLKOUT0_CLKOUT2_NO_COUNT  (CLKOUT0_REGS[22]),

      // CLKOUT1
      .CLKOUT1_CLKOUT1_HIGH_TIME (CLKOUT1_REGS[11:6]),
      .CLKOUT1_CLKOUT1_LOW_TIME  (CLKOUT1_REGS[5:0]),
      .CLKOUT1_CLKOUT1_PHASE_MUX (CLKOUT1_REGS[15:13]),
      .CLKOUT1_CLKOUT2_DELAY_TIME(CLKOUT1_REGS[21:16]),
      .CLKOUT1_CLKOUT2_EDGE      (CLKOUT1_REGS[23]),
      .CLKOUT1_CLKOUT2_NO_COUNT  (CLKOUT1_REGS[22]),

      // CLKOUT2
      .CLKOUT2_CLKOUT1_HIGH_TIME (CLKOUT2_REGS[11:6]),
      .CLKOUT2_CLKOUT1_LOW_TIME  (CLKOUT2_REGS[5:0]),
      .CLKOUT2_CLKOUT1_PHASE_MUX (CLKOUT2_REGS[15:13]),
      .CLKOUT2_CLKOUT2_DELAY_TIME(CLKOUT2_REGS[21:16]),
      .CLKOUT2_CLKOUT2_EDGE      (CLKOUT2_REGS[23]),
      .CLKOUT2_CLKOUT2_NO_COUNT  (CLKOUT2_REGS[22]),

      // CLKOUT3
      .CLKOUT3_CLKOUT1_HIGH_TIME (CLKOUT3_REGS[11:6]),
      .CLKOUT3_CLKOUT1_LOW_TIME  (CLKOUT3_REGS[5:0]),
      .CLKOUT3_CLKOUT1_PHASE_MUX (CLKOUT3_REGS[15:13]),
      .CLKOUT3_CLKOUT2_DELAY_TIME(CLKOUT3_REGS[21:16]),
      .CLKOUT3_CLKOUT2_EDGE      (CLKOUT3_REGS[23]),
      .CLKOUT3_CLKOUT2_NO_COUNT  (CLKOUT3_REGS[22]),

      // CLKOUT4
      .CLKOUT4_CLKOUT1_HIGH_TIME (CLKOUT4_REGS[11:6]),
      .CLKOUT4_CLKOUT1_LOW_TIME  (CLKOUT4_REGS[5:0]),
      .CLKOUT4_CLKOUT1_PHASE_MUX (CLKOUT4_REGS[15:13]),
      .CLKOUT4_CLKOUT2_DELAY_TIME(CLKOUT4_REGS[21:16]),
      .CLKOUT4_CLKOUT2_EDGE      (CLKOUT4_REGS[23]),
      .CLKOUT4_CLKOUT2_NO_COUNT  (CLKOUT4_REGS[22]),

      // CLKOUT5
      .CLKOUT5_CLKOUT1_HIGH_TIME (CLKOUT5_REGS[11:6]),
      .CLKOUT5_CLKOUT1_LOW_TIME  (CLKOUT5_REGS[5:0]),
      .CLKOUT5_CLKOUT1_PHASE_MUX (CLKOUT5_REGS[15:13]),
      .CLKOUT5_CLKOUT2_DELAY_TIME(CLKOUT5_REGS[21:16]),
      .CLKOUT5_CLKOUT2_EDGE      (CLKOUT5_REGS[23]),
      .CLKOUT5_CLKOUT2_NO_COUNT  (CLKOUT5_REGS[22]),

      // Clock output enable controls
      .CLKFBOUT_CLKOUT1_OUTPUT_ENABLE(_TECHMAP_CONSTVAL_CLKFBOUT_ === 1'bX),

      .CLKOUT0_CLKOUT1_OUTPUT_ENABLE(_TECHMAP_CONSTVAL_CLKOUT0_ === 1'bX),
      .CLKOUT1_CLKOUT1_OUTPUT_ENABLE(_TECHMAP_CONSTVAL_CLKOUT1_ === 1'bX),
      .CLKOUT2_CLKOUT1_OUTPUT_ENABLE(_TECHMAP_CONSTVAL_CLKOUT2_ === 1'bX),
      .CLKOUT3_CLKOUT1_OUTPUT_ENABLE(_TECHMAP_CONSTVAL_CLKOUT3_ === 1'bX),
      .CLKOUT4_CLKOUT1_OUTPUT_ENABLE(_TECHMAP_CONSTVAL_CLKOUT4_ === 1'bX),
      .CLKOUT5_CLKOUT1_OUTPUT_ENABLE(_TECHMAP_CONSTVAL_CLKOUT5_ === 1'bX)
  ) _TECHMAP_REPLACE_ (
      .CLKFBIN (CLKFBIN),
      .CLKIN1  (CLKIN1),
      .CLKIN2  (CLKIN2),
      .CLKFBOUT(CLKFBOUT),
      .CLKOUT0 (CLKOUT0),
      .CLKOUT1 (CLKOUT1),
      .CLKOUT2 (CLKOUT2),
      .CLKOUT3 (CLKOUT3),
      .CLKOUT4 (CLKOUT4),
      .CLKOUT5 (CLKOUT5),

      .CLKINSEL(clkinsel),

      .PWRDWN(pwrdwn),
      .RST   (rst),
      .LOCKED(LOCKED),

      .DCLK (dclk),
      .DEN  (den),
      .DWE  (dwe),
      .DRDY (DRDY),
      .DADDR(DADDR),
      .DI   (DI),
      .DO   (DO)
  );

endmodule

// PLLE2_BASE
module PLLE2_BASE (
    input CLKFBIN,
    input CLKIN,

    output CLKFBOUT,
    output CLKOUT0,
    output CLKOUT1,
    output CLKOUT2,
    output CLKOUT3,
    output CLKOUT4,
    output CLKOUT5,

    input  RST,
    output LOCKED
);

  parameter IS_CLKINSEL_INVERTED = 1'b0;
  parameter IS_RST_INVERTED = 1'b0;

  parameter BANDWIDTH = "OPTIMIZED";
  parameter STARTUP_WAIT = "FALSE";

  parameter CLKIN1_PERIOD = 0.0;
  parameter REF_JITTER1 = 0.1;

  parameter [5:0] DIVCLK_DIVIDE = 1;

  parameter [5:0] CLKFBOUT_MULT = 1;
  parameter signed CLKFBOUT_PHASE = 0;

  parameter [6:0] CLKOUT0_DIVIDE = 1;
  parameter CLKOUT0_DUTY_CYCLE = 50000;
  parameter signed CLKOUT0_PHASE = 0;

  parameter [6:0] CLKOUT1_DIVIDE = 1;
  parameter CLKOUT1_DUTY_CYCLE = 50000;
  parameter signed CLKOUT1_PHASE = 0;

  parameter [6:0] CLKOUT2_DIVIDE = 1;
  parameter CLKOUT2_DUTY_CYCLE = 50000;
  parameter signed CLKOUT2_PHASE = 0;

  parameter [6:0] CLKOUT3_DIVIDE = 1;
  parameter CLKOUT3_DUTY_CYCLE = 50000;
  parameter signed CLKOUT3_PHASE = 0;

  parameter [6:0] CLKOUT4_DIVIDE = 1;
  parameter CLKOUT4_DUTY_CYCLE = 50000;
  parameter signed CLKOUT4_PHASE = 0;

  parameter [6:0] CLKOUT5_DIVIDE = 1;
  parameter CLKOUT5_DUTY_CYCLE = 50000;
  parameter signed CLKOUT5_PHASE = 0;

  // The substituted cell
  PLLE2_ADV #(
      .IS_CLKINSEL_INVERTED(IS_CLKINSEL_INVERTED),
      .IS_RST_INVERTED(IS_RST_INVERTED),
      .IS_PWRDWN_INVERTED(1'b0),

      .BANDWIDTH(BANDWIDTH),
      .STARTUP_WAIT(STARTUP_WAIT),

      .CLKIN1_PERIOD(CLKIN1_PERIOD),
      .REF_JITTER1  (REF_JITTER1),

      .DIVCLK_DIVIDE(DIVCLK_DIVIDE),

      .CLKFBOUT_MULT (CLKFBOUT_MULT),
      .CLKFBOUT_PHASE(CLKFBOUT_PHASE),

      .CLKOUT0_DIVIDE(CLKOUT0_DIVIDE),
      .CLKOUT0_DUTY_CYCLE(CLKOUT0_DUTY_CYCLE),
      .CLKOUT0_PHASE(CLKOUT0_PHASE),

      .CLKOUT1_DIVIDE(CLKOUT1_DIVIDE),
      .CLKOUT1_DUTY_CYCLE(CLKOUT1_DUTY_CYCLE),
      .CLKOUT1_PHASE(CLKOUT1_PHASE),

      .CLKOUT2_DIVIDE(CLKOUT2_DIVIDE),
      .CLKOUT2_DUTY_CYCLE(CLKOUT2_DUTY_CYCLE),
      .CLKOUT2_PHASE(CLKOUT2_PHASE),

      .CLKOUT3_DIVIDE(CLKOUT3_DIVIDE),
      .CLKOUT3_DUTY_CYCLE(CLKOUT3_DUTY_CYCLE),
      .CLKOUT3_PHASE(CLKOUT3_PHASE),

      .CLKOUT4_DIVIDE(CLKOUT4_DIVIDE),
      .CLKOUT4_DUTY_CYCLE(CLKOUT4_DUTY_CYCLE),
      .CLKOUT4_PHASE(CLKOUT4_PHASE),

      .CLKOUT5_DIVIDE(CLKOUT5_DIVIDE),
      .CLKOUT5_DUTY_CYCLE(CLKOUT5_DUTY_CYCLE),
      .CLKOUT5_PHASE(CLKOUT5_PHASE)
  ) _TECHMAP_REPLACE_ (
      .CLKFBIN (CLKFBIN),
      .CLKIN1  (CLKIN),
      .CLKINSEL(1'b1),

      .CLKFBOUT(CLKFBOUT),
      .CLKOUT0 (CLKOUT0),
      .CLKOUT1 (CLKOUT1),
      .CLKOUT2 (CLKOUT2),
      .CLKOUT3 (CLKOUT3),
      .CLKOUT4 (CLKOUT4),
      .CLKOUT5 (CLKOUT5),

      .PWRDWN(1'b0),
      .RST(RST),
      .LOCKED(LOCKED),

      .DCLK(1'b0),
      .DEN(1'b0),
      .DWE(1'b0),
      .DRDY(),
      .DADDR(7'd0),
      .DI(16'd0),
      .DO()
  );

endmodule
