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

module inpad (
    output Q,
    (* iopad_external_pin *)
    input  P
);
  assign Q = P;
endmodule

module outpad (
    (* iopad_external_pin *)
    output P,
    input  A
);
  assign P = A;
endmodule

module ckpad (
    output Q,
    (* iopad_external_pin *)
    input  P
);
  assign Q = P;
endmodule

module bipad (
    input  A,
    input  EN,
    output Q,
    (* iopad_external_pin *)
    inout  P
);
  assign Q = P;
  assign P = EN ? A : 1'bz;
endmodule


module dff (
    output reg Q,
    input D,
    (* clkbuf_sink *)
    input CLK
);
  parameter [0:0] INIT = 1'b0;
  initial Q = INIT;
  always @(posedge CLK) Q <= D;
endmodule

