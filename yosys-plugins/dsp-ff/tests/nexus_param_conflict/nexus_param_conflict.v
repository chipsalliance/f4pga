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

module conflict_dsp_ctrl_param (
    input  wire        CLK,
    input  wire [ 8:0] A,
    input  wire [ 8:0] B,
    output reg  [17:0] Z,
);

    wire [17:0] z;
    always @(posedge CLK)
        Z <= z;

    MULT9X9 # (
        .REGINPUTA("BYPASS"),
        .REGINPUTB("BYPASS"),
        .REGOUTPUT("REGISTER")
    ) mult (
        .A (A),
        .B (B),
        .Z (z)
    );

endmodule

module conflict_dsp_common_param (
    input  wire        CLK,
    input  wire        RST,
    input  wire [ 8:0] A,
    input  wire [ 8:0] B,
    output wire [17:0] Z,
);

    wire [8:0] ra;
    always @(posedge CLK or posedge RST)
        if (RST) ra <= 0;
        else     ra <= A;

    wire [8:0] rb;
    always @(posedge CLK)
        if (RST) rb <= 0;
        else     rb <= B;

    MULT9X9 # (
        .REGINPUTA("BYPASS"),
        .REGINPUTB("BYPASS"),
        .REGOUTPUT("BYPASS")
    ) mult (
        .A (ra),
        .B (rb),
        .Z (Z)
    );

endmodule

module conflict_ff_param (
    input  wire        CLK,
    input  wire        RST,
    input  wire [ 8:0] A,
    input  wire [ 8:0] B,
    output wire [17:0] Z,
);

    wire [8:0] ra;
    always @(posedge CLK or posedge RST)
        if (RST) ra[8:4] <= 0;
        else     ra[8:4] <= A[8:4];

    always @(posedge CLK)
        if (RST) ra[3:0] <= 0;
        else     ra[3:0] <= A[3:0];

    MULT9X9 # (
        .REGINPUTA("BYPASS"),
        .REGINPUTB("BYPASS"),
        .REGOUTPUT("BYPASS")
    ) mult (
        .A (ra),
        .B (B),
        .Z (Z)
    );

endmodule

