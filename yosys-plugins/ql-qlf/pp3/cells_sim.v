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

module inv (
    output Q,
    input  A
);
  assign Q = A ? 0 : 1;
endmodule

module buff (
    output Q,
    input  A
);
  assign Q = A;
endmodule

module logic_0 (
    output a
);
  assign a = 0;
endmodule

module logic_1 (
    output a
);
  assign a = 1;
endmodule

module gclkbuff (
    input  A,
    output Z
);
  specify
    (A => Z) = 0;
  endspecify

  assign Z = A;
endmodule

module inpad (
    output Q,
    (* iopad_external_pin *)
    input  P
);
  specify
    (P => Q) = 0;
  endspecify
  assign Q = P;
endmodule

module outpad (
    (* iopad_external_pin *)
    output P,
    input  A
);
  specify
    (A => P) = 0;
  endspecify
  assign P = A;
endmodule

module ckpad (
    output Q,
    (* iopad_external_pin *)
    input  P
);
  specify
    (P => Q) = 0;
  endspecify
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

module dffc (
    output reg Q,
    input D,
    (* clkbuf_sink *)
    input CLK,
    (* clkbuf_sink *)
    input CLR
);
  parameter [0:0] INIT = 1'b0;
  initial Q = INIT;

  always @(posedge CLK or posedge CLR)
    if (CLR) Q <= 1'b0;
    else Q <= D;
endmodule

module dffp (
    output reg Q,
    input D,
    (* clkbuf_sink *)
    input CLK,
    (* clkbuf_sink *)
    input PRE
);
  parameter [0:0] INIT = 1'b0;
  initial Q = INIT;

  always @(posedge CLK or posedge PRE)
    if (PRE) Q <= 1'b1;
    else Q <= D;
endmodule

module dffpc (
    output reg Q,
    input D,
    (* clkbuf_sink *)
    input CLK,
    (* clkbuf_sink *)
    input CLR,
    (* clkbuf_sink *)
    input PRE
);
  parameter [0:0] INIT = 1'b0;
  initial Q = INIT;

  always @(posedge CLK or posedge CLR or posedge PRE)
    if (CLR) Q <= 1'b0;
    else if (PRE) Q <= 1'b1;
    else Q <= D;
endmodule

module dffe (
    output reg Q,
    input D,
    (* clkbuf_sink *)
    input CLK,
    input EN
);
  parameter [0:0] INIT = 1'b0;
  initial Q = INIT;
  always @(posedge CLK) if (EN) Q <= D;
endmodule

module dffec (
    output reg Q,
    input D,
    (* clkbuf_sink *)
    input CLK,
    input EN,
    (* clkbuf_sink *)
    input CLR
);
  parameter [0:0] INIT = 1'b0;
  initial Q = INIT;

  always @(posedge CLK or posedge CLR)
    if (CLR) Q <= 1'b0;
    else if (EN) Q <= D;
endmodule

(* lib_whitebox *)
module dffepc (
    output reg Q,
    input D,
    (* clkbuf_sink *)
    input CLK,
    input EN,
    (* clkbuf_sink *)
    input CLR,
    (* clkbuf_sink *)
    input PRE
);
  parameter [0:0] INIT = 1'b0;

  specify
    if (EN) (posedge CLK => (Q : D)) = 1701;  // QCK -> QZ
    if (CLR) (CLR => Q) = 967;  // QRT -> QZ
    if (PRE) (PRE => Q) = 1252;  // QST -> QZ
    $setup(D, posedge CLK, 216);  // QCK -> QDS
    $setup(EN, posedge CLK, 590);  // QCK -> QEN
  endspecify

  initial Q = INIT;
  always @(posedge CLK or posedge CLR or posedge PRE)
    if (CLR) Q <= 1'b0;
    else if (PRE) Q <= 1'b1;
    else if (EN) Q <= D;
endmodule

//                  FZ       FS F2 (F1 TO 0)
(* abc9_box, lib_whitebox *)
module AND2I0 (
    output Q,
    input  A,
    B
);
  specify
    (A => Q) = 698;  // FS -> FZ
    (B => Q) = 639;  // F2 -> FZ
  endspecify

  assign Q = A ? B : 0;
endmodule

(* abc9_box, lib_whitebox *)
module mux2x0 (
    output Q,
    input  S,
    A,
    B
);
  specify
    (S => Q) = 698;  // FS -> FZ
    (A => Q) = 639;  // F1 -> FZ
    (B => Q) = 639;  // F2 -> FZ
  endspecify

  assign Q = S ? B : A;
endmodule

(* abc9_box, lib_whitebox *)
module mux2x1 (
    output Q,
    input  S,
    A,
    B
);
  specify
    (S => Q) = 698;  // FS -> FZ
    (A => Q) = 639;  // F1 -> FZ
    (B => Q) = 639;  // F2 -> FZ
  endspecify

  assign Q = S ? B : A;
endmodule

(* abc9_box, lib_whitebox *)
module mux4x0 (
    output Q,
    input  S0,
    S1,
    A,
    B,
    C,
    D
);
  specify
    (S0 => Q) = 1251;  // TAB -> TZ
    (S1 => Q) = 1406;  // TSL -> TZ
    (A => Q) = 1699;  // TA1 -> TZ
    (B => Q) = 1687;  // TA2 -> TZ
    (C => Q) = 1669;  // TB1 -> TZ
    (D => Q) = 1679;  // TB2 -> TZ
  endspecify

  assign Q = S1 ? (S0 ? D : C) : (S0 ? B : A);
endmodule

// S0 BSL TSL
// S1 BAB TAB
// S2 TBS
// A TA1
// B TA2
// C TB1
// D TB2
// E BA1
// F BA2
// G BB1
// H BB2
// Q CZ
(* abc9_box, lib_whitebox *)
module mux8x0 (
    output Q,
    input  S0,
    S1,
    S2,
    A,
    B,
    C,
    D,
    E,
    F,
    G,
    H
);
  specify
    (S0 => Q) = 1593;  // ('TSL', 'BSL') -> CZ
    (S1 => Q) = 1437;  // ('TAB', 'BAB') -> CZ
    (S2 => Q) = 995;  // TBS -> CZ
    (A => Q) = 1887;  // TA1 -> CZ
    (B => Q) = 1873;  // TA2 -> CZ
    (C => Q) = 1856;  // TB1 -> CZ
    (D => Q) = 1860;  // TB2 -> CZ
    (E => Q) = 1714;  // BA1 -> CZ
    (F => Q) = 1773;  // BA2 -> CZ
    (G => Q) = 1749;  // BB1 -> CZ
    (H => Q) = 1723;  // BB2 -> CZ
  endspecify

  assign Q = S2 ? (S1 ? (S0 ? H : G) : (S0 ? F : E)) : (S1 ? (S0 ? D : C) : (S0 ? B : A));
endmodule

(* abc9_lut=1, lib_whitebox *)
module LUT1 (
    output O,
    input  I0
);
  parameter [1:0] INIT = 0;
  parameter EQN = "(I0)";

  // These timings are for PolarPro 3E; other families will need updating.
  specify
    (I0 => O) = 698;  // FS -> FZ
  endspecify

  assign O = I0 ? INIT[1] : INIT[0];
endmodule

//               TZ        TSL TAB
(* abc9_lut=2, lib_whitebox *)
module LUT2 (
    output O,
    input  I0,
    I1
);
  parameter [3:0] INIT = 4'h0;
  parameter EQN = "(I0)";

  // These timings are for PolarPro 3E; other families will need updating.
  specify
    (I0 => O) = 1251;  // TAB -> TZ
    (I1 => O) = 1406;  // TSL -> TZ
  endspecify

  wire [1:0] s1 = I1 ? INIT[3:2] : INIT[1:0];
  assign O = I0 ? s1[1] : s1[0];
endmodule

(* abc9_lut=2, lib_whitebox *)
module LUT3 (
    output O,
    input  I0,
    I1,
    I2
);
  parameter [7:0] INIT = 8'h0;
  parameter EQN = "(I0)";

  // These timings are for PolarPro 3E; other families will need updating.
  specify
    (I0 => O) = 1251;  // TAB -> TZ
    (I1 => O) = 1406;  // TSL -> TZ
    (I2 => O) = 1699;  // ('TA1', 'TA2', 'TB1', 'TB2') -> TZ
  endspecify

  wire [3:0] s2 = I2 ? INIT[7:4] : INIT[3:0];
  wire [1:0] s1 = I1 ? s2[3:2] : s2[1:0];
  assign O = I0 ? s1[1] : s1[0];
endmodule

(* abc9_lut=4, lib_whitebox *)
module LUT4 (
    output O,
    input  I0,
    I1,
    I2,
    I3
);
  parameter [15:0] INIT = 16'h0;
  parameter EQN = "(I0)";

  // These timings are for PolarPro 3E; other families will need updating.
  specify
    (I0 => O) = 995;  // TBS -> CZ
    (I1 => O) = 1437;  // ('TAB', 'BAB') -> CZ
    (I2 => O) = 1593;  // ('TSL', 'BSL') -> CZ
    (I3 => O) = 1887;  // ('TA1', 'TA2', 'TB1', 'TB2', 'BA1', 'BA2', 'BB1', 'BB2') -> CZ
  endspecify

  wire [7:0] s3 = I3 ? INIT[15:8] : INIT[7:0];
  wire [3:0] s2 = I2 ? s3[7:4] : s3[3:0];
  wire [1:0] s1 = I1 ? s2[3:2] : s2[1:0];
  assign O = I0 ? s1[1] : s1[0];
endmodule

module logic_cell_macro (
    input  BA1,
    input  BA2,
    input  BAB,
    input  BAS1,
    input  BAS2,
    input  BB1,
    input  BB2,
    input  BBS1,
    input  BBS2,
    input  BSL,
    input  F1,
    input  F2,
    input  FS,
    input  QCK,
    input  QCKS,
    input  QDI,
    input  QDS,
    input  QEN,
    input  QRT,
    input  QST,
    input  TA1,
    input  TA2,
    input  TAB,
    input  TAS1,
    input  TAS2,
    input  TB1,
    input  TB2,
    input  TBS,
    input  TBS1,
    input  TBS2,
    input  TSL,
    output CZ,
    output FZ,
    output QZ,
    output TZ
);

  wire TAP1, TAP2, TBP1, TBP2, BAP1, BAP2, BBP1, BBP2, QCKP, TAI, TBI, BAI, BBI, TZI, BZI, CZI, QZI;
  reg QZ_r;

  assign QZ   = QZ_r;
  assign TAP1 = TAS1 ? ~TA1 : TA1;
  assign TAP2 = TAS2 ? ~TA2 : TA2;
  assign TBP1 = TBS1 ? ~TB1 : TB1;
  assign TBP2 = TBS2 ? ~TB2 : TB2;
  assign BAP1 = BAS1 ? ~BA1 : BA1;
  assign BAP2 = BAS2 ? ~BA2 : BA2;
  assign BBP1 = BBS1 ? ~BB1 : BB1;
  assign BBP2 = BBS2 ? ~BB2 : BB2;

  assign TAI  = TSL ? TAP2 : TAP1;
  assign TBI  = TSL ? TBP2 : TBP1;
  assign BAI  = BSL ? BAP2 : BAP1;
  assign BBI  = BSL ? BBP2 : BBP1;
  assign TZI  = TAB ? TBI : TAI;
  assign BZI  = BAB ? BBI : BAI;
  assign CZI  = TBS ? BZI : TZI;
  assign QZI  = QDS ? QDI : CZI;
  assign FZ   = FS ? F2 : F1;
  assign TZ   = TZI;
  assign CZ   = CZI;
  assign QCKP = QCKS ? QCK : ~QCK;

  initial QZ_r <= 1'b0;

  always @(posedge QCKP or posedge QRT or posedge QST) begin
    if (QRT)
        QZ_r <= 1'b0;
    else if (QST)
        QZ_r <= 1'b1;
    else if (QEN)
        QZ_r <= QZI;
  end

endmodule

// Include simulation models of QLAL4S3B eFPGA interface
`include "qlal4s3b_sim.v"
// Include simulation models for QLAL3 hard blocks
`include "qlal3_sim.v"
// Include BRAM and FIFO simulation models
`include "brams_sim.v"
// Include MULT simulation models
`include "mult_sim.v"

