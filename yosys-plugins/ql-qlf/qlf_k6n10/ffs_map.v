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

// Basic DFF

module \$_DFF_P_ (D, C, Q);
    input D;
    input C;
    output Q;
    parameter _TECHMAP_WIREINIT_Q_ = 1'bx;
    dff _TECHMAP_REPLACE_ (.Q(Q), .D(D), .C(C));
endmodule

// Async reset
module \$_DFF_PP0_ (D, C, R, Q);
    input D;
    input C;
    input R;
    output Q;
    parameter _TECHMAP_WIREINIT_Q_ = 1'bx;
    dffr _TECHMAP_REPLACE_ (.Q(Q), .D(D), .C(C), .R(R));
endmodule

// Async set
module \$_DFF_PP1_ (D, C, R, Q);
    input D;
    input C;
    input R;
    output Q;
    dffs _TECHMAP_REPLACE_ (.Q(Q), .D(D), .C(C), .S(R));
endmodule

// Async reset, enable

module  \$_DFFE_PP0P_ (D, C, E, R, Q);
    input D;
    input C;
    input E;
    input R;
    output Q;
    parameter _TECHMAP_WIREINIT_Q_ = 1'bx;
    dffre  _TECHMAP_REPLACE_ (.D(D), .Q(Q), .C(C), .E(E), .R(R));
endmodule

// Async set, enable

module  \$_DFFE_PP1P_ (D, C, E, R, Q);
    input D;
    input C;
    input E;
    input R;
    output Q;
    parameter _TECHMAP_WIREINIT_Q_ = 1'bx;
    dffse  _TECHMAP_REPLACE_ (.D(D), .Q(Q), .C(C), .E(E), .S(S));
endmodule

// Async set & reset

module \$_DFFSR_PPP_ (D, C, R, S, Q);
    input D;
    input C;
    input R;
    input S;
    output Q;
    dffsr _TECHMAP_REPLACE_ (.Q(Q), .D(D), .C(C), .R(R), .S(S));
endmodule

// Async set, reset & enable

module \$_DFFSRE_PPPP_ (D, Q, C, E, R, S);
    input D;
    input C;
    input E;
    input R;
    input S;
    output Q;
    dffsre _TECHMAP_REPLACE_ (.Q(Q), .D(D), .C(C), .E(E), .R(R), .S(S));
endmodule

// Latch with async set and reset
module  \$_DLATCHSR_PPP_ (input E, S, R, D, output Q);
    parameter _TECHMAP_WIREINIT_Q_ = 1'bx;
    latchsre _TECHMAP_REPLACE_ (.D(D), .Q(Q), .E(1'b1), .G(E),  .R(R), .S(S));
endmodule

// The following techmap operation are not performed right now
// as Negative edge FF are not legalized in synth_quicklogic for qlf_k6n10
// but in case we implement clock inversion in the future, the support is ready for it.

module \$_DFF_N_ (D, C, Q);
    input D;
    input C;
    output Q;
    parameter _TECHMAP_WIREINIT_Q_ = 1'bx;
    dff #(.IS_C_INVERTED(1'b1)) _TECHMAP_REPLACE_ (.Q(Q), .D(D), .C(C));
endmodule

module \$_DFF_NP0_ (D, C, R, Q);
    input D;
    input C;
    input R;
    output Q;
    parameter _TECHMAP_WIREINIT_Q_ = 1'bx;
    dffr #(.IS_C_INVERTED(1'b1)) _TECHMAP_REPLACE_ (.Q(Q), .D(D), .C(C), .R(R));
endmodule

module \$_DFF_NP1_ (D, C, R, Q);
    input D;
    input C;
    input R;
    output Q;
    dffs #(.IS_C_INVERTED(1'b1)) _TECHMAP_REPLACE_ (.Q(Q), .D(D), .C(C), .S(R));
endmodule

module  \$_DFFE_NP0P_ (D, C, E, R, Q);
    input D;
    input C;
    input E;
    input R;
    output Q;
    parameter _TECHMAP_WIREINIT_Q_ = 1'bx;
    dffre #(.IS_C_INVERTED(1'b1)) _TECHMAP_REPLACE_ (.D(D), .Q(Q), .C(C), .E(E), .R(R));
endmodule

module  \$_DFFE_NP1P_ (D, C, E, R, Q);
    input D;
    input C;
    input E;
    input R;
    output Q;
    parameter _TECHMAP_WIREINIT_Q_ = 1'bx;
    dffse #(.IS_C_INVERTED(1'b1)) _TECHMAP_REPLACE_ (.D(D), .Q(Q), .C(C), .E(E), .S(S));
endmodule

module \$_DFFSR_NPP_ (D, C, R, S, Q);
    input D;
    input C;
    input R;
    input S;
    output Q;
    dffsr #(.IS_C_INVERTED(1'b1)) _TECHMAP_REPLACE_ (.Q(Q), .D(D), .C(C), .R(R), .S(S));
endmodule

module \$_DFFSRE_PPPP_ (D, C, E, R, S, Q);
    input D;
    input C;
    input E;
    input R;
    input S;
    output Q;
    dffsre #(.IS_C_INVERTED(1'b1)) _TECHMAP_REPLACE_ (.Q(Q), .D(D), .C(C), .E(E), .R(R), .S(S));
endmodule
