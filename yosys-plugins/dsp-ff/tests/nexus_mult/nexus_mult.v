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

module mult_ireg (
    input  wire        CLK,
    input  wire [ 8:0] A,
    input  wire [ 8:0] B,
    output wire [17:0] Z
);

    reg [8:0] ra;
    always @(posedge CLK)
        ra <= A;

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

module mult_oreg (
    input  wire        CLK,
    input  wire [ 8:0] A,
    input  wire [ 8:0] B,
    output reg  [17:0] Z
);

    reg [17:0] z;
    always @(posedge CLK)
        Z <= z;

    MULT9X9 # (
        .REGINPUTA("BYPASS"),
        .REGINPUTB("BYPASS"),
        .REGOUTPUT("BYPASS")
    ) mult (
        .A (A),
        .B (B),
        .Z (z)
    );

endmodule

module mult_all (
    input  wire        CLK,
    input  wire [ 8:0] A,
    input  wire [ 8:0] B,
    output reg  [17:0] Z
);

    reg [8:0] ra;
    always @(posedge CLK)
        ra <= A;

    reg [8:0] rb;
    always @(posedge CLK)
        rb <= B;

    reg [17:0] z;
    always @(posedge CLK)
        Z <= z;

    MULT9X9 # (
        .REGINPUTA("BYPASS"),
        .REGINPUTB("BYPASS"),
        .REGOUTPUT("BYPASS")
    ) mult (
        .A (ra),
        .B (rb),
        .Z (z)
    );

endmodule

module mult_ctrl (
    input  wire        CLK,
    input  wire [ 8:0] A,
    input  wire        SA,
    input  wire [ 8:0] B,
    output wire [17:0] Z
);

    reg [8:0] ra;
    reg       rsa;

    always @(posedge CLK) begin
        ra  <= A;
        rsa <= SA;
    end

    MULT9X9 # (
        .REGINPUTA("BYPASS"),
        .REGINPUTB("BYPASS"),
        .REGOUTPUT("BYPASS")
    ) mult (
        .A          (ra),
        .SIGNEDA    (rsa),
        .B          (B),
        .Z          (Z)
    );

endmodule

