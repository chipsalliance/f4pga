// Copyright (C) 2020-2021  The SymbiFlow Authors.
//
// Use of this source code is governed by a ISC-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/ISC
//
// SPDX-License-Identifier:ISC

// ============================================================================
// CMT

// PLLE2_ADV_VPR
(* blackbox *)
module PLLE2_ADV_VPR (
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

  parameter [0:0] INV_CLKINSEL = 1'd0;
  parameter [0:0] ZINV_PWRDWN = 1'd0;
  parameter [0:0] ZINV_RST = 1'd1;

  parameter [0:0] STARTUP_WAIT = 1'd0;

  // Tables
  parameter [9:0] TABLE = 10'd0;
  parameter [39:0] LKTABLE = 40'd0;
  parameter [15:0] POWER_REG = 16'd0;
  parameter [11:0] FILTREG1_RESERVED = 12'd0;
  parameter [9:0] FILTREG2_RESERVED = 10'd0;
  parameter [5:0] LOCKREG1_RESERVED = 6'd0;
  parameter [0:0] LOCKREG2_RESERVED = 1'b0;
  parameter [0:0] LOCKREG3_RESERVED = 1'b0;

  // DIVCLK
  parameter [5:0] DIVCLK_DIVCLK_HIGH_TIME = 6'd0;
  parameter [5:0] DIVCLK_DIVCLK_LOW_TIME = 6'd0;
  parameter [0:0] DIVCLK_DIVCLK_NO_COUNT = 1'b1;
  parameter [0:0] DIVCLK_DIVCLK_EDGE = 1'b0;

  // CLKFBOUT
  parameter [5:0] CLKFBOUT_CLKOUT1_HIGH_TIME = 6'd0;
  parameter [5:0] CLKFBOUT_CLKOUT1_LOW_TIME = 6'd0;
  parameter [0:0] CLKFBOUT_CLKOUT1_OUTPUT_ENABLE = 1'b0;
  parameter [2:0] CLKFBOUT_CLKOUT1_PHASE_MUX = 3'd0;
  parameter [5:0] CLKFBOUT_CLKOUT2_DELAY_TIME = 6'd0;
  parameter [0:0] CLKFBOUT_CLKOUT2_EDGE = 1'b0;
  parameter [2:0] CLKFBOUT_CLKOUT2_FRAC = 3'd0;
  parameter [0:0] CLKFBOUT_CLKOUT2_FRAC_EN = 1'b0;
  parameter [0:0] CLKFBOUT_CLKOUT2_FRAC_WF_R = 1'b0;
  parameter [0:0] CLKFBOUT_CLKOUT2_NO_COUNT = 1'b1;

  // CLKOUT0
  parameter [5:0] CLKOUT0_CLKOUT1_HIGH_TIME = 6'd0;
  parameter [5:0] CLKOUT0_CLKOUT1_LOW_TIME = 6'd0;
  parameter [0:0] CLKOUT0_CLKOUT1_OUTPUT_ENABLE = 1'b0;
  parameter [2:0] CLKOUT0_CLKOUT1_PHASE_MUX = 3'd0;
  parameter [5:0] CLKOUT0_CLKOUT2_DELAY_TIME = 6'd0;
  parameter [0:0] CLKOUT0_CLKOUT2_EDGE = 1'b0;
  parameter [2:0] CLKOUT0_CLKOUT2_FRAC = 3'd0;
  parameter [0:0] CLKOUT0_CLKOUT2_FRAC_EN = 1'b0;
  parameter [0:0] CLKOUT0_CLKOUT2_FRAC_WF_R = 1'b0;
  parameter [0:0] CLKOUT0_CLKOUT2_NO_COUNT = 1'b1;

  // CLKOUT1
  parameter [5:0] CLKOUT1_CLKOUT1_HIGH_TIME = 6'd0;
  parameter [5:0] CLKOUT1_CLKOUT1_LOW_TIME = 6'd0;
  parameter [0:0] CLKOUT1_CLKOUT1_OUTPUT_ENABLE = 1'b0;
  parameter [2:0] CLKOUT1_CLKOUT1_PHASE_MUX = 3'd0;
  parameter [5:0] CLKOUT1_CLKOUT2_DELAY_TIME = 6'd0;
  parameter [0:0] CLKOUT1_CLKOUT2_EDGE = 1'b0;
  parameter [2:0] CLKOUT1_CLKOUT2_FRAC = 3'd0;
  parameter [0:0] CLKOUT1_CLKOUT2_FRAC_EN = 1'b0;
  parameter [0:0] CLKOUT1_CLKOUT2_FRAC_WF_R = 1'b0;
  parameter [0:0] CLKOUT1_CLKOUT2_NO_COUNT = 1'b1;

  // CLKOUT2
  parameter [5:0] CLKOUT2_CLKOUT1_HIGH_TIME = 6'd0;
  parameter [5:0] CLKOUT2_CLKOUT1_LOW_TIME = 6'd0;
  parameter [0:0] CLKOUT2_CLKOUT1_OUTPUT_ENABLE = 1'b0;
  parameter [2:0] CLKOUT2_CLKOUT1_PHASE_MUX = 3'd0;
  parameter [5:0] CLKOUT2_CLKOUT2_DELAY_TIME = 6'd0;
  parameter [0:0] CLKOUT2_CLKOUT2_EDGE = 1'b0;
  parameter [2:0] CLKOUT2_CLKOUT2_FRAC = 3'd0;
  parameter [0:0] CLKOUT2_CLKOUT2_FRAC_EN = 1'b0;
  parameter [0:0] CLKOUT2_CLKOUT2_FRAC_WF_R = 1'b0;
  parameter [0:0] CLKOUT2_CLKOUT2_NO_COUNT = 1'b1;

  // CLKOUT3
  parameter [5:0] CLKOUT3_CLKOUT1_HIGH_TIME = 6'd0;
  parameter [5:0] CLKOUT3_CLKOUT1_LOW_TIME = 6'd0;
  parameter [0:0] CLKOUT3_CLKOUT1_OUTPUT_ENABLE = 1'b0;
  parameter [2:0] CLKOUT3_CLKOUT1_PHASE_MUX = 3'd0;
  parameter [5:0] CLKOUT3_CLKOUT2_DELAY_TIME = 6'd0;
  parameter [0:0] CLKOUT3_CLKOUT2_EDGE = 1'b0;
  parameter [2:0] CLKOUT3_CLKOUT2_FRAC = 3'd0;
  parameter [0:0] CLKOUT3_CLKOUT2_FRAC_EN = 1'b0;
  parameter [0:0] CLKOUT3_CLKOUT2_FRAC_WF_R = 1'b0;
  parameter [0:0] CLKOUT3_CLKOUT2_NO_COUNT = 1'b1;

  // CLKOUT4
  parameter [5:0] CLKOUT4_CLKOUT1_HIGH_TIME = 6'd0;
  parameter [5:0] CLKOUT4_CLKOUT1_LOW_TIME = 6'd0;
  parameter [0:0] CLKOUT4_CLKOUT1_OUTPUT_ENABLE = 1'b0;
  parameter [2:0] CLKOUT4_CLKOUT1_PHASE_MUX = 3'd0;
  parameter [5:0] CLKOUT4_CLKOUT2_DELAY_TIME = 6'd0;
  parameter [0:0] CLKOUT4_CLKOUT2_EDGE = 1'b0;
  parameter [2:0] CLKOUT4_CLKOUT2_FRAC = 3'd0;
  parameter [0:0] CLKOUT4_CLKOUT2_FRAC_EN = 1'b0;
  parameter [0:0] CLKOUT4_CLKOUT2_FRAC_WF_R = 1'b0;
  parameter [0:0] CLKOUT4_CLKOUT2_NO_COUNT = 1'b1;

  // CLKOUT5
  parameter [5:0] CLKOUT5_CLKOUT1_HIGH_TIME = 6'd0;
  parameter [5:0] CLKOUT5_CLKOUT1_LOW_TIME = 6'd0;
  parameter [0:0] CLKOUT5_CLKOUT1_OUTPUT_ENABLE = 1'b0;
  parameter [2:0] CLKOUT5_CLKOUT1_PHASE_MUX = 3'd0;
  parameter [5:0] CLKOUT5_CLKOUT2_DELAY_TIME = 6'd0;
  parameter [0:0] CLKOUT5_CLKOUT2_EDGE = 1'b0;
  parameter [2:0] CLKOUT5_CLKOUT2_FRAC = 3'd0;
  parameter [0:0] CLKOUT5_CLKOUT2_FRAC_EN = 1'b0;
  parameter [0:0] CLKOUT5_CLKOUT2_FRAC_WF_R = 1'b0;
  parameter [0:0] CLKOUT5_CLKOUT2_NO_COUNT = 1'b1;


  // TODO: Compensation parameters

  // TODO: How to simulate a PLL in verilog (i.e. the VCO) ???

endmodule
