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

module \$_DFF_P_ (D, Q, C);
    input D;
    input C;
    output Q;
    dffsr _TECHMAP_REPLACE_ (.Q(Q), .D(D), .C(C),  .R(1'b1), .S(1'b1));
endmodule

module \$_DFF_PN0_ (D, Q, C, R);
    input D;
    input C;
    input R;
    output Q;
    dffsr _TECHMAP_REPLACE_ (.Q(Q), .D(D), .C(C), .R(R), .S(1'b1));
endmodule

module \$_DFF_PP0_ (D, Q, C, R); 
    input D;
    input C;
    input R;
    output Q;
    dffsr _TECHMAP_REPLACE_ (.Q(Q), .D(D), .C(C), .R(!R), .S(1'b1));
endmodule

module \$_DFF_PN1_ (D, Q, C, R);
    input D;
    input C;
    input R;
    output Q;
    dffsr _TECHMAP_REPLACE_ (.Q(Q), .D(D), .C(C), .R(1'b1), .S(R));
endmodule

module \$_DFF_PP1_ (D, Q, C, R);
    input D;
    input C;
    input R;
    output Q;
    dffsr _TECHMAP_REPLACE_ (.Q(Q), .D(D), .C(C), .R(1'b1), .S(!R));
endmodule

module \$_DFF_N_ (D, Q, C);
    input D;
    input C;
    output Q;
    dffnsr _TECHMAP_REPLACE_ (.Q(Q), .D(D), .C(C), .R(1'b1), .S(1'b1));
endmodule

module \$_DFF_NN0_ (D, Q, C, R);
    input D;
    input C;
    input R;
    output Q;
    dffnsr _TECHMAP_REPLACE_ (.Q(Q), .D(D), .C(C), .R(R), .S(1'b1));
endmodule

module \$_DFF_NP0_ (D, Q, C, R);
    input D;
    input C;
    input R;
    output Q;
    dffnsr _TECHMAP_REPLACE_ (.Q(Q), .D(D), .C(C), .R(!R), .S(1'b1));
endmodule

module \$_DFF_NN1_ (D, Q, C, R);
    input D;
    input C;
    input R;
    output Q;
    dffnsr _TECHMAP_REPLACE_ (.Q(Q), .D(D), .C(C), .R(1'b1), .S(R));
endmodule

module \$_DFF_NP1_ (D, Q, C, R);
    input D;
    input C;
    input R;
    output Q;
    dffnsr _TECHMAP_REPLACE_ (.Q(Q), .D(D), .C(C), .R(1'b1), .S(!R));
endmodule

module \$_DFFSR_PPP_ (D, Q, C, R, S);
    input D;
    input C;
    input R;
    input S;
    output Q;
    dffsr _TECHMAP_REPLACE_ (.Q(Q), .D(D), .C(C), .R(!R), .S(!S));
endmodule

module \$_DFFSR_PNP_ (D, Q, C, R, S);
    input D;
    input C;
    input R;
    input S;
    output Q;
    dffsr _TECHMAP_REPLACE_ (.Q(Q), .D(D), .C(C), .R(!R), .S(S));
endmodule

module \$_DFFSR_PNN_ (D, Q, C, R, S);
    input D;
    input C;
    input R;
    input S;
    output Q;
    dffsr _TECHMAP_REPLACE_ (.Q(Q), .D(D), .C(C), .R(R), .S(S));
endmodule

module \$_DFFSR_PPN_ (D, Q, C, R, S);
    input D;
    input C;
    input R;
    input S;
    output Q;
    dffsr _TECHMAP_REPLACE_ (.Q(Q), .D(D), .C(C), .R(R), .S(!S));
endmodule

module \$_DFFSR_NPP_ (D, Q, C, R, S);
    input D;
    input C;
    input R;
    input S;
    output Q;
    dffnsr _TECHMAP_REPLACE_ (.Q(Q), .D(D), .C(C), .R(!R), .S(!S));
endmodule

module \$_DFFSR_NNP_ (D, Q, C, R, S);
    input D;
    input C;
    input R;
    input S;
    output Q;
    dffnsr _TECHMAP_REPLACE_ (.Q(Q), .D(D), .C(C), .R(!R), .S(S));
endmodule

module \$_DFFSR_NNN_ (D, Q, C, R, S);
    input D;
    input C;
    input R;
    input S;
    output Q;
    dffnsr _TECHMAP_REPLACE_ (.Q(Q), .D(D), .C(C), .R(R), .S(S));
endmodule

module \$_DFFSR_NPN_ (D, Q, C, R, S);
    input D;
    input C;
    input R;
    input S;
    output Q;
    dffnsr _TECHMAP_REPLACE_ (.Q(Q), .D(D), .C(C), .R(R), .S(!S));
endmodule

module \$__SHREG_DFF_P_ (D, Q, C);
    input D;
    input C;
    output Q;

    parameter DEPTH = 2;
    reg [DEPTH-2:0] q;
    genvar i;
    generate for (i = 0; i < DEPTH; i = i + 1) begin: slice


        // First in chain
        generate if (i == 0) begin
                 sh_dff #() shreg_beg (
                    .Q(q[i]),
                    .D(D),
                    .C(C)
                );
        end endgenerate
        // Middle in chain
        generate if (i > 0 && i != DEPTH-1) begin
                 sh_dff #() shreg_mid (
                    .Q(q[i]),
                    .D(q[i-1]),
                    .C(C)
                );
        end endgenerate
        // Last in chain
        generate if (i == DEPTH-1) begin
                 sh_dff #() shreg_end (
                    .Q(Q),
                    .D(q[i-1]),
                    .C(C)
                );
        end endgenerate
   end: slice
   endgenerate

endmodule
