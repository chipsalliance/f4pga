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
    input  clk,
    input  cpu_reset,
    input  data_in,
    output data_out
);

  wire data_out;
  wire builder_pll_fb;
  wire main_locked;

  PLLE2_ADV #(
      .CLKFBOUT_MULT(4'd12),
      .CLKIN1_PERIOD(10.0),
      .CLKOUT0_DIVIDE(4'd12),
      .CLKOUT0_PHASE(0.0),
      .DIVCLK_DIVIDE(1'd1),
      .REF_JITTER1(0.01),
      .STARTUP_WAIT("FALSE")
  ) PLLE2_ADV (
      .CLKFBIN(builder_pll_fb),
      .CLKIN1(clk),
      .RST(cpu_reset),
      .CLKFBOUT(builder_pll_fb),
      .CLKOUT0(main_clkout0),
      .CLKOUT1(main_clkout1),
      .CLKOUT2(main_clkout2),
      .CLKOUT3(main_clkout3),
      .CLKOUT4(main_clkout4),
      .LOCKED(main_locked)
  );

  FDCE FDCE_PLLx1_PH0 (
      .D  (data_in),
      .C  (main_clkout0),
      .CE (1'b1),
      .CLR(1'b0),
      .Q  (data_out)
  );

endmodule
