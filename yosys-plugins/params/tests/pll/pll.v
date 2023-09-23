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
