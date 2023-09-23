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

module conflict_dsp_clk (
    input  wire        CLK_A,
    input  wire        CLK_B,
    input  wire [ 8:0] A,
    input  wire [ 8:0] B,
    output wire [17:0] Z
);

    reg [8:0] ra;
    always @(posedge CLK_A)
        ra <= A;

    reg [8:0] rb;
    always @(posedge CLK_B)
        rb <= B;

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

module conflict_ff_clk (
    input  wire        CLK1,
    input  wire        CLK2,
    input  wire [ 8:0] A,
    input  wire [ 8:0] B,
    output wire [17:0] Z
);

    reg [17:0] z;

    always @(posedge CLK1)
        Z[17:9] <= z[17:9];
    always @(posedge CLK2)
        Z[ 8:0] <= z[ 8:0];

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

module conflict_ff_rst (
    input  wire        CLK,
    input  wire        RST1,
    input  wire        RST2,
    input  wire [ 8:0] A,
    input  wire [ 8:0] B,
    output wire [17:0] Z
);

    reg [17:0] z;

    always @(posedge CLK or posedge RST1)
        if (RST1)
            Z[17:9] <= 0;
        else
            Z[17:9] <= z[17:9];
    always @(posedge CLK or posedge RST2)
        if (RST2)
            Z[ 8:0] <= 0;
        else
            Z[ 8:0] <= z[ 8:0];

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

module conflict_ff_ena (
    input  wire        CLK,
    input  wire        ENA1,
    input  wire        ENA2,
    input  wire [ 8:0] A,
    input  wire [ 8:0] B,
    output wire [17:0] Z
);

    reg [17:0] z;

    always @(posedge CLK)
        if (ENA1)
            Z[17:9] <= z[17:9];
    always @(posedge CLK)
        if (ENA2)
            Z[ 8:0] <= z[ 8:0];

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

module conflict_dsp_port (
    input  wire        CLK_A,
    input  wire [ 8:0] A,
    input  wire        SA,
    input  wire [ 8:0] B,
    output wire [17:0] Z
);

    reg [8:0] ra;
    always @(posedge CLK_A)
        ra <= A;

    MULT9X9 # (
        .REGINPUTA("BYPASS"),
        .REGINPUTB("BYPASS"),
        .REGOUTPUT("BYPASS")
    ) mult (
        .A       (ra),
        .SIGNEDA (SA),
        .B       (B),
        .Z       (Z)
    );

endmodule
