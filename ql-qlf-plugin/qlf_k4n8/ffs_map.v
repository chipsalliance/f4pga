// Copyright (C) 2020-2021  The SymbiFlow Authors.
//
// Use of this source code is governed by a ISC-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/ISC
//
// SPDX-License-Identifier:ISC

module \$_DFF_P_ (D, Q, C);
    input D;
    input C;
    output Q;
    dff _TECHMAP_REPLACE_ (.Q(Q), .D(D), .C(C));
endmodule

module \$_DFF_PN0_ (D, Q, C, R);
    input D;
    input C;
    input R;
    output Q;
    dffr _TECHMAP_REPLACE_ (.Q(Q), .D(D), .C(C), .R(R));
endmodule

module \$_DFF_PP0_ (D, Q, C, R);
    input D;
    input C;
    input R;
    output Q;
    dffr _TECHMAP_REPLACE_ (.Q(Q), .D(D), .C(C), .R(!R));
endmodule

module \$_DFF_PN1_ (D, Q, C, R);
    input D;
    input C;
    input R;
    output Q;
    dffs _TECHMAP_REPLACE_ (.Q(Q), .D(D), .C(C), .S(R));
endmodule

module \$_DFF_PP1_ (D, Q, C, R);
    input D;
    input C;
    input R;
    output Q;
    dffs _TECHMAP_REPLACE_ (.Q(Q), .D(D), .C(C), .S(!R));
endmodule

module \$_DFF_N_ (D, Q, C);
    input D;
    input C;
    output Q;
    dffn _TECHMAP_REPLACE_ (.Q(Q), .D(D), .C(C));
endmodule

module \$_DFF_NN0_ (D, Q, C, R);
    input D;
    input C;
    input R;
    output Q;
    dffnr _TECHMAP_REPLACE_ (.Q(Q), .D(D), .C(C), .R(R));
endmodule

module \$_DFF_NP0_ (D, Q, C, R);
    input D;
    input C;
    input R;
    output Q;
    dffnr _TECHMAP_REPLACE_ (.Q(Q), .D(D), .C(C), .R(!R));
endmodule

module \$_DFF_NN1_ (D, Q, C, R);
    input D;
    input C;
    input R;
    output Q;
    dffns _TECHMAP_REPLACE_ (.Q(Q), .D(D), .C(C), .S(R));
endmodule

module \$_DFF_NP1_ (D, Q, C, R);
    input D;
    input C;
    input R;
    output Q;
    dffns _TECHMAP_REPLACE_ (.Q(Q), .D(D), .C(C), .S(!R));
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
