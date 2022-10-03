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

module fsm (
    clock,
    reset,
    req_0,
    req_1,
    gnt_0,
    gnt_1
);
  input clock, reset, req_0, req_1;
  output gnt_0, gnt_1;
  wire clock, reset, req_0, req_1;
  reg gnt_0, gnt_1;

  parameter SIZE = 3;
  parameter IDLE = 3'b001;
  parameter GNT0 = 3'b010;
  parameter GNT1 = 3'b100;
  parameter GNT2 = 3'b101;

  reg [SIZE-1:0] state;
  reg [SIZE-1:0] next_state;

  always @(posedge clock) begin : FSM
    if (reset == 1'b1) begin
      state <= #1 IDLE;
      gnt_0 <= 0;
      gnt_1 <= 0;
    end else
      case (state)
        IDLE:
        if (req_0 == 1'b1) begin
          state <= #1 GNT0;
          gnt_0 <= 1;
        end else if (req_1 == 1'b1) begin
          gnt_1 <= 1;
          state <= #1 GNT0;
        end else begin
          state <= #1 IDLE;
        end
        GNT0:
        if (req_0 == 1'b1) begin
          state <= #1 GNT0;
        end else begin
          gnt_0 <= 0;
          state <= #1 IDLE;
        end
        GNT1:
        if (req_1 == 1'b1) begin
          state <= #1 GNT2;
          gnt_1 <= req_0;
        end
        GNT2:
        if (req_0 == 1'b1) begin
          state <= #1 GNT1;
          gnt_1 <= req_1;
        end
        default: state <= #1 IDLE;
      endcase
  end
endmodule
