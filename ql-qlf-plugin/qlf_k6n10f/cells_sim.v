// Copyright (C) 2020-2021  The SymbiFlow Authors.
//
// Use of this source code is governed by a ISC-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/ISC
//
// SPDX-License-Identifier:ISC

(* abc9_flop, lib_whitebox *)
module sh_dff(
    output reg Q,
    input D,
    (* clkbuf_sink *)
    input C
);
    parameter [0:0] INIT = 1'b0;
    initial Q = INIT;

    always @(posedge C)
            Q <= D;
endmodule

(* abc9_box, lib_blackbox *)
module adder_carry(
    output sumout,
    output cout,
    input p,
    input g,
    input cin
);
    assign sumout = p ^ cin;
    assign cout = p ? cin : g;

endmodule

(* abc9_box, lib_whitebox *)
module adder_lut5(
   output lut5_out,
   (* abc9_carry *)
   output cout,
   input [0:4] in,
   (* abc9_carry *)
   input cin
);
    parameter [0:15] LUT=0;
    parameter IN2_IS_CIN = 0;

    wire [0:4] li = (IN2_IS_CIN) ? {in[0], in[1], cin, in[3], in[4]} : {in[0], in[1], in[2], in[3],in[4]};

    // Output function
    wire [0:15] s1 = li[0] ?
        {LUT[0], LUT[2], LUT[4], LUT[6], LUT[8], LUT[10], LUT[12], LUT[14], LUT[16], LUT[18], LUT[20], LUT[22], LUT[24], LUT[26], LUT[28], LUT[30]}:
        {LUT[1], LUT[3], LUT[5], LUT[7], LUT[9], LUT[11], LUT[13], LUT[15], LUT[17], LUT[19], LUT[21], LUT[23], LUT[25], LUT[27], LUT[29], LUT[31]};

    wire [0:7] s2 = li[1] ? {s1[0], s1[2], s1[4], s1[6], s1[8], s1[10], s1[12], s1[14]} :
                            {s1[1], s1[3], s1[5], s1[7], s1[9], s1[11], s1[13], s1[15]};

    wire [0:3] s3 = li[2] ? {s2[0], s2[2], s2[4], s2[6]} : {s2[1], s2[3], s2[5], s2[7]};
    wire [0:1] s4 = li[3] ? {s3[0], s3[2]} : {s3[1], s3[3]};

    assign lut5_out = li[4] ? s4[0] : s4[1];

    // Carry out function
    assign cout = (s3[2]) ? cin : s3[3];

endmodule



(* abc9_lut=1, lib_whitebox *)
module frac_lut6(
    input [0:5] in,
    output [0:3] lut4_out,
    output [0:1] lut5_out,
    output lut6_out
);
    parameter [0:63] LUT = 0;
    // Effective LUT input
    wire [0:5] li = in;

    // Output function
    wire [0:31] s1 = li[0] ?
    {LUT[0] , LUT[2] , LUT[4] , LUT[6] , LUT[8] , LUT[10], LUT[12], LUT[14], 
     LUT[16], LUT[18], LUT[20], LUT[22], LUT[24], LUT[26], LUT[28], LUT[30],
     LUT[32], LUT[34], LUT[36], LUT[38], LUT[40], LUT[42], LUT[44], LUT[46],
     LUT[48], LUT[50], LUT[52], LUT[54], LUT[56], LUT[58], LUT[60], LUT[62]}:
    {LUT[1] , LUT[3] , LUT[5] , LUT[7] , LUT[9] , LUT[11], LUT[13], LUT[15], 
     LUT[17], LUT[19], LUT[21], LUT[23], LUT[25], LUT[27], LUT[29], LUT[31],
     LUT[33], LUT[35], LUT[37], LUT[39], LUT[41], LUT[43], LUT[45], LUT[47],
     LUT[49], LUT[51], LUT[53], LUT[55], LUT[57], LUT[59], LUT[61], LUT[63]};

    wire [0:15] s2 = li[1] ?
    {s1[0] , s1[2] , s1[4] , s1[6] , s1[8] , s1[10], s1[12], s1[14],
     s1[16], s1[18], s1[20], s1[22], s1[24], s1[26], s1[28], s1[30]}:
    {s1[1] , s1[3] , s1[5] , s1[7] , s1[9] , s1[11], s1[13], s1[15],
     s1[17], s1[19], s1[21], s1[23], s1[25], s1[27], s1[29], s1[31]};

    wire [0:7] s3 = li[2] ?
    {s2[0], s2[2], s2[4], s2[6], s2[8], s2[10], s2[12], s2[14]}:
    {s2[1], s2[3], s2[5], s2[7], s2[9], s2[11], s2[13], s2[15]};

    wire [0:3] s4 = li[3] ? {s3[0], s3[2], s3[4], s3[6]}:
                            {s3[1], s3[3], s3[5], s3[7]};

    wire [0:1] s5 = li[4] ? {s4[0], s4[2]} : {s4[1], s4[3]};

    assign lut4_out[0] = s4[0];
    assign lut4_out[1] = s4[1];
    assign lut4_out[2] = s4[2];
    assign lut4_out[3] = s4[3];

    assign lut5_out[0] = s5[0];
    assign lut5_out[1] = s5[1];

    assign lut6_out = li[5] ? s5[0] : s5[1];

endmodule

(* abc9_flop, lib_whitebox *)
module dff(
    output reg Q,
    input D,
    (* clkbuf_sink *)
    (* invertible_pin = "IS_C_INVERTED" *)
    input C
);
    parameter [0:0] INIT = 1'b0;
    parameter [0:0] IS_C_INVERTED = 1'b0;
    initial Q = INIT;
    case(|IS_C_INVERTED)
          1'b0:
            always @(posedge C)
                Q <= D;
          1'b1:
            always @(negedge C)
                Q <= D;
    endcase
endmodule

(* abc9_flop, lib_whitebox *)
module dffr(
    output reg Q,
    input D,
    input R,
    (* clkbuf_sink *)
    (* invertible_pin = "IS_C_INVERTED" *)
    input C
);
    parameter [0:0] INIT = 1'b0;
    parameter [0:0] IS_C_INVERTED = 1'b0;
    initial Q = INIT;
    case(|IS_C_INVERTED)
          1'b0:
            always @(posedge C or posedge R)
                if (R)
                        Q <= 1'b0;
                else
                        Q <= D;
          1'b1:
            always @(negedge C or posedge R)
                if (R)
                        Q <= 1'b0;
                else
                        Q <= D;
    endcase
endmodule

(* abc9_flop, lib_whitebox *)
module dffre(
    output reg Q,
    input D,
    input R,
    input E,
    (* clkbuf_sink *)
    (* invertible_pin = "IS_C_INVERTED" *)
    input C
);
    parameter [0:0] INIT = 1'b0;
    parameter [0:0] IS_C_INVERTED = 1'b0;
    initial Q = INIT;
    case(|IS_C_INVERTED)
          1'b0:
            always @(posedge C or posedge R)
              if (R)
                Q <= 1'b0;
              else if(E)
                Q <= D;
          1'b1:
            always @(negedge C or posedge R)
              if (R)
                Q <= 1'b0;
              else if(E)
                Q <= D;
        endcase
endmodule

module dffs(
    output reg Q,
    input D,
    (* clkbuf_sink *)
    (* invertible_pin = "IS_C_INVERTED" *)
    input C,
    input S
);
    parameter [0:0] INIT = 1'b0;
    parameter [0:0] IS_C_INVERTED = 1'b0;
    initial Q = INIT;
    case(|IS_C_INVERTED)
          1'b0:
            always @(posedge C or negedge S)
              if (S)
                Q <= 1'b1;
              else
                Q <= D;
          1'b1:
            always @(negedge C or negedge S)
              if (S)
                Q <= 1'b1;
              else
                Q <= D;
        endcase
endmodule

module dffse(
    output reg Q,
    input D,
    (* clkbuf_sink *)
    (* invertible_pin = "IS_C_INVERTED" *)
    input C,
    input S,
    input E
);
    parameter [0:0] INIT = 1'b0;
    parameter [0:0] IS_C_INVERTED = 1'b0;
    initial Q = INIT;
    case(|IS_C_INVERTED)
          1'b0:
            always @(posedge C or negedge S)
              if (S)
                Q <= 1'b1;
              else if(E)
                Q <= D;
          1'b1:
            always @(negedge C or negedge S)
              if (S)
                Q <= 1'b1;
              else if(E)
                Q <= D;
        endcase
endmodule

module dffsr(
    output reg Q,
    input D,
    (* clkbuf_sink *)
    (* invertible_pin = "IS_C_INVERTED" *)
    input C,
    input R,
    input S
);
    parameter [0:0] INIT = 1'b0;
    parameter [0:0] IS_C_INVERTED = 1'b0;
    initial Q = INIT;
    case(|IS_C_INVERTED)
          1'b0:
            always @(posedge C or negedge S or negedge R)
              if (S)
                Q <= 1'b1;
              else if (R)
                Q <= 1'b0;
              else
                Q <= D;
          1'b1:
            always @(negedge C or negedge S or negedge R)
              if (S)
                Q <= 1'b1;
              else if (R)
                Q <= 1'b0;
              else
                Q <= D;
        endcase
endmodule

module dffsre(
    output reg Q,
    input D,
    (* clkbuf_sink *)
    input C,
    input E,
    input R,
    input S
);
    parameter [0:0] INIT = 1'b0;
    initial Q = INIT;

        always @(posedge C or negedge S or negedge R)
          if (!R)
            Q <= 1'b0;
          else if (!S)
            Q <= 1'b1;
          else if (E)
            Q <= D;
        
endmodule

module dffnsre(
    output reg Q,
    input D,
    (* clkbuf_sink *)
    input C,
    input E,
    input R,
    input S
);
    parameter [0:0] INIT = 1'b0;
    initial Q = INIT;

        always @(negedge C or negedge S or negedge R)
          if (!R)
            Q <= 1'b0;
          else if (!S)
            Q <= 1'b1;
          else if (E)
            Q <= D;
        
endmodule

(* abc9_flop, lib_whitebox *)
module latchsre (
    output reg Q,
    input S,
    input R,
    input D,
    input G,
    input E
);
    parameter [0:0] INIT = 1'b0;
    initial Q = INIT;
    always @*
      begin
        if (!R) 
          Q <= 1'b0;
        else if (!S) 
          Q <= 1'b1;
        else if (E && G) 
          Q <= D;
      end
endmodule

(* abc9_flop, lib_whitebox *)
module latchnsre (
    output reg Q,
    input S,
    input R,
    input D,
    input G,
    input E
);
    parameter [0:0] INIT = 1'b0;
    initial Q = INIT;
    always @*
      begin
        if (!R) 
          Q <= 1'b0;
        else if (!S) 
          Q <= 1'b1;
        else if (E && !G) 
          Q <= D;
      end
endmodule

(* abc9_flop, lib_whitebox *)
module scff(
    output reg Q,
    input D,
    input clk
);
    parameter [0:0] INIT = 1'b0;
    initial Q = INIT;

    always @(posedge clk)
            Q <= D;
endmodule

module TDP_BRAM18 (
    (* clkbuf_sink *)
    input CLOCKA,
    (* clkbuf_sink *)
    input CLOCKB,
    input READENABLEA,
    input READENABLEB,
    input [13:0] ADDRA,
    input [13:0] ADDRB,
    input [15:0] WRITEDATAA,
    input [15:0] WRITEDATAB,
    input [1:0] WRITEDATAAP,
    input [1:0] WRITEDATABP,
    input WRITEENABLEA,
    input WRITEENABLEB,
    input [1:0] BYTEENABLEA,
    input [1:0] BYTEENABLEB,
    //input [2:0] WRITEDATAWIDTHA,
    //input [2:0] WRITEDATAWIDTHB,
    //input [2:0] READDATAWIDTHA,
    //input [2:0] READDATAWIDTHB,
    output [15:0] READDATAA,
    output [15:0] READDATAB,
    output [1:0] READDATAAP,
    output [1:0] READDATABP
);
    parameter INITP_00 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INITP_01 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INITP_02 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INITP_03 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INITP_04 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INITP_05 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INITP_06 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INITP_07 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_00 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_01 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_02 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_03 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_04 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_05 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_06 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_07 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_08 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_09 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_0A = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_0B = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_0C = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_0D = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_0E = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_0F = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_10 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_11 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_12 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_13 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_14 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_15 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_16 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_17 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_18 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_19 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_1A = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_1B = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_1C = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_1D = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_1E = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_1F = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_20 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_21 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_22 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_23 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_24 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_25 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_26 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_27 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_28 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_29 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_2A = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_2B = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_2C = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_2D = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_2E = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_2F = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_30 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_31 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_32 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_33 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_34 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_35 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_36 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_37 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_38 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_39 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_3A = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_3B = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_3C = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_3D = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_3E = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_3F = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter integer READ_WIDTH_A = 0;
    parameter integer READ_WIDTH_B = 0;
    parameter integer WRITE_WIDTH_A = 0;
    parameter integer WRITE_WIDTH_B = 0;

endmodule

module TDP_BRAM36 (
    (* clkbuf_sink *)
    input CLOCKA,
    (* clkbuf_sink *)
    input CLOCKB,
    input READENABLEA,
    input READENABLEB,
    input [14:0] ADDRA,
    input [14:0] ADDRB,
    input [31:0] WRITEDATAA,
    input [31:0] WRITEDATAB,
    input [3:0] WRITEDATAAP,
    input [3:0] WRITEDATABP,
    input WRITEENABLEA,
    input WRITEENABLEB,
    input [3:0] BYTEENABLEA,
    input [3:0] BYTEENABLEB,
    //input [2:0] WRITEDATAWIDTHA,
    //input [2:0] WRITEDATAWIDTHB,
    //input [2:0] READDATAWIDTHA,
    //input [2:0] READDATAWIDTHB,
    output [31:0] READDATAA,
    output [31:0] READDATAB,
    output [3:0] READDATAAP,
    output [3:0] READDATABP
);
    parameter INITP_00 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INITP_01 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INITP_02 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INITP_03 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INITP_04 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INITP_05 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INITP_06 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INITP_07 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INITP_08 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INITP_09 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INITP_0A = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INITP_0B = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INITP_0C = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INITP_0D = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INITP_0E = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INITP_0F = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_00 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_01 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_02 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_03 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_04 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_05 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_06 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_07 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_08 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_09 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_0A = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_0B = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_0C = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_0D = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_0E = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_0F = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_10 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_11 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_12 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_13 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_14 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_15 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_16 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_17 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_18 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_19 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_1A = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_1B = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_1C = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_1D = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_1E = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_1F = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_20 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_21 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_22 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_23 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_24 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_25 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_26 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_27 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_28 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_29 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_2A = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_2B = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_2C = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_2D = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_2E = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_2F = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_30 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_31 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_32 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_33 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_34 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_35 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_36 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_37 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_38 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_39 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_3A = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_3B = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_3C = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_3D = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_3E = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_3F = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_40 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_41 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_42 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_43 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_44 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_45 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_46 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_47 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_48 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_49 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_4A = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_4B = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_4C = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_4D = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_4E = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_4F = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_50 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_51 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_52 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_53 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_54 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_55 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_56 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_57 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_58 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_59 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_5A = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_5B = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_5C = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_5D = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_5E = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_5F = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_60 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_61 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_62 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_63 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_64 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_65 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_66 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_67 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_68 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_69 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_6A = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_6B = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_6C = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_6D = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_6E = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_6F = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_70 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_71 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_72 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_73 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_74 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_75 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_76 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_77 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_78 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_79 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_7A = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_7B = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_7C = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_7D = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_7E = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter INIT_7F = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    parameter integer READ_WIDTH_A = 0;
    parameter integer READ_WIDTH_B = 0;
    parameter integer WRITE_WIDTH_A = 0;
    parameter integer WRITE_WIDTH_B = 0;

endmodule

(* blackbox *)
module QL_DSP1 (
    input  [19:0] a,
    input  [17:0] b,
    (* clkbuf_sink *)
    input  clk0,
    (* clkbuf_sink *)
    input  clk1,
    input  [ 1:0] feedback0,
    input  [ 1:0] feedback1,
    input  load_acc0,
    input  load_acc1,
    input  reset0,
    input  reset1,
    output reg [37:0] z
);
    parameter MODE_BITS = 27'b00000000000000000000000000;
endmodule  /* QL_DSP1 */

(* blackbox *)
module QL_DSP2 ( // TODO: Name subject to change
    input  [19:0] a,
    input  [17:0] b,
    input  [ 3:0] acc_fir,
    output [37:0] z,
    output [17:0] dly_b,

    (* clkbuf_sink *)
    input         clk,
    input         reset,

    input  [1:0]  feedback,
    input         load_acc,
    input         unsigned_a,
    input         unsigned_b,

    input         f_mode,
    input  [2:0]  output_select,
    input         saturate_enable,
    input  [5:0]  shift_right,
    input         round,
    input         subtract,
    input         register_inputs
);

    parameter [19:0] COEFF_0 = 20'd0;
    parameter [19:0] COEFF_1 = 20'd0;
    parameter [19:0] COEFF_2 = 20'd0;
    parameter [19:0] COEFF_3 = 20'd0;

endmodule

module dsp_t1_sim # (
    parameter NBITS_ACC = 64,
    parameter NBITS_A   = 20,
    parameter NBITS_B   = 18,
    parameter NBITS_Z   = 38,

    parameter [0:0] SATURATE_ENABLE   = 0,
    parameter [2:0] OUTPUT_SELECT     = 0,
    parameter [0:0] ROUND             = 0,
    //parameter [0:0] LOAD_ACC          = 0,
    parameter [0:0] SUBTRACT          = 0,
    parameter [0:0] REGISTER_INPUTS   = 0
    //parameter [0:0] REGISTER_OUTPUTS  = 0
)(
    input  [NBITS_A-1:0] a_i,
    input  [NBITS_B-1:0] b_i,
    output [NBITS_Z-1:0] z_o,
    output [NBITS_B-1:0] dly_b_o,

    input         unsigned_a_i,
    input         unsigned_b_i,

    input         clock_i,
    input         reset_n_i,

    input         load_acc_i,
    input [1:0]   feedback_i,
    input [5:0]   shift_right_i
);

    if (NBITS_ACC < NBITS_A + NBITS_B)
        $error("NBITS_ACC must be > NBITS_A + NBITS_B");

    // Input registers
    reg  [NBITS_A-1:0]  r_a;
    reg  [NBITS_B-1:0]  r_b;
    reg                 r_unsigned_a;
    reg                 r_unsigned_b;
    reg                 r_load_acc;
    reg  [1:0]          r_feedback;
    reg  [5:0]          r_shift_d1;
    reg  [5:0]          r_shift_d2;

    always @(posedge clock_i or negedge reset_n_i) begin
        if (~reset_n_i) begin

            r_a <= 'h0;
            r_b <= 'h0;

            r_unsigned_a <= 0;
            r_unsigned_b <= 0;
            r_feedback   <= 0;
            r_shift_d1   <= 0;
            r_shift_d2   <= 0;
//            r_subtract   <= 0;
            r_load_acc   <= 0;

        end else begin

            r_a <= a_i;
            r_b <= b_i;

            r_unsigned_a <= unsigned_a_i;
            r_unsigned_b <= unsigned_b_i;
            r_feedback   <= feedback_i;
            r_shift_d1   <= shift_right_i;
            r_shift_d2   <= r_shift_d1;
//            r_subtract   <= subtract_i;
            r_load_acc   <= load_acc_i;

        end
    end

    // Registered / non-registered input path select
    wire [NBITS_A-1:0]  a = REGISTER_INPUTS ? r_a : a_i;
    wire [NBITS_B-1:0]  b = REGISTER_INPUTS ? r_b : b_i;

    wire       unsigned_a = REGISTER_INPUTS ? r_unsigned_a : unsigned_a_i;
    wire       unsigned_b = REGISTER_INPUTS ? r_unsigned_b : unsigned_b_i;
    wire [1:0] feedback   = REGISTER_INPUTS ? r_feedback   : feedback_i;
    wire       load_acc   = REGISTER_INPUTS ? r_load_acc   : load_acc_i;
    //wire       subtract   = REGISTER_INPUTS ? r_subtract   : subtract_i;

    // Shift right control
    localparam SHIFT_SEL = {REGISTER_INPUTS, OUTPUT_SELECT[1]};
    wire [5:0] shift_right = (SHIFT_SEL == 2'b00) ?   shift_right_i :
                             (SHIFT_SEL == 2'b01) ?   r_shift_d1 :
                             (SHIFT_SEL == 2'b10) ?   r_shift_d1 :
                           /*(SHIFT_SEL == 2'b11) ?*/ r_shift_d2;

    // Multiplier
    wire [NBITS_A-1:0] mult_a = (feedback == 2'h3) ? acc[NBITS_A-1:0] : a;
    wire [NBITS_B-1:0] mult_b = (feedback == 2'h2) ? {NBITS_B{1'b0}}  : b;

    wire [NBITS_A-1:0] mult_sgn_a = mult_a[NBITS_A-1];
    wire [NBITS_A-1:0] mult_mag_a = (mult_sgn_a) ? (~mult_a + 1) : mult_a;
    wire [NBITS_B-1:0] mult_sgn_b = mult_b[NBITS_B-1];
    wire [NBITS_B-1:0] mult_mag_b = (mult_sgn_b) ? (~mult_b + 1) : mult_b;

    wire [NBITS_A+NBITS_B-1:0] mult_mag = mult_mag_a * mult_mag_b;
    wire mult_sgn = mult_sgn_a ^ mult_sgn_b;

    wire [NBITS_A+NBITS_B-1:0] mult = (unsigned_a && unsigned_b) ?
        (mult_a * mult_b) : (mult_sgn ? (~mult_mag + 1) : mult_mag);

    // Sign extension
    wire [NBITS_ACC-1:0] mult_xtnd = (unsigned_a && unsigned_b) ?
        {{(NBITS_ACC-NBITS_A-NBITS_B){1'b0}},                    mult[NBITS_A+NBITS_B-1:0]} :
        {{(NBITS_ACC-NBITS_A-NBITS_B){mult[NBITS_A+NBITS_B-1]}}, mult[NBITS_A+NBITS_B-1:0]};

    wire [NBITS_ACC-1:0] a_xtnd = (unsigned_a) ?
        {{(NBITS_ACC-NBITS_A){1'b0}},         a[NBITS_A-1:0]} :
        {{(NBITS_ACC-NBITS_A){a[NBITS_A-1]}}, a[NBITS_A-1:0]};

    // Adder
    wire [NBITS_ACC-1:0] add_a = (SUBTRACT) ? (~mult_xtnd + 1) : mult_xtnd;
    wire [NBITS_ACC-1:0] add_b = (feedback == 2'h0) ? acc :
                                 (feedback == 2'h1) ? {{NBITS_ACC}{1'b0}} :
                                                      a_xtnd;

    wire [NBITS_ACC-1:0] add_o = add_a + add_b;    

    // Accumulator
    reg [NBITS_ACC-1:0] acc;
    always @(posedge clock_i or negedge reset_n_i)
        if (~reset_n_i) acc <= 'h0;
        else begin
            if (load_acc)
                acc <= add_o;
            else
                acc <= acc;
        end

    // Adder/accumulator output selection
    wire [NBITS_ACC-1:0] acc_out = (OUTPUT_SELECT[1]) ? add_o : acc;

    // Round, shift, saturate
    wire [NBITS_ACC-1:0] acc_rnd = (ROUND && (shift_right != 0)) ? (acc_out + ({{(NBITS_ACC-1){1'b0}}, 1'b1} << (shift_right - 1))) :
                                                                    acc_out;

    wire [NBITS_ACC-1:0] acc_shr = (unsigned_a && unsigned_b) ? (acc_rnd  >> shift_right) :
                                                                (acc_rnd >>> shift_right);

    wire [NBITS_ACC-1:0] acc_sat_u = (acc_shr[NBITS_ACC-1:NBITS_Z] != 0) ? {{(NBITS_ACC-NBITS_Z){1'b0}},{NBITS_Z{1'b1}}} :
                                                                           {{(NBITS_ACC-NBITS_Z){1'b0}},{acc_shr[NBITS_Z-1:0]}};

    wire [NBITS_ACC-1:0] acc_sat_s = ((|acc_shr[NBITS_ACC-1:NBITS_Z-1] == 1'b0) ||
                                      (&acc_shr[NBITS_ACC-1:NBITS_Z-1] == 1'b1)) ? {{(NBITS_ACC-NBITS_Z){1'b0}},{acc_shr[NBITS_Z-1:0]}} :
                                                                                   {{(NBITS_ACC-NBITS_Z){1'b0}},{acc_shr[NBITS_ACC-1],{NBITS_Z-1{~acc_shr[NBITS_ACC-1]}}}};

    wire [NBITS_ACC-1:0] acc_sat = (SATURATE_ENABLE) ? ((unsigned_a && unsigned_b) ? acc_sat_u : acc_sat_s) : acc_shr;

    // Output signals
    wire [NBITS_Z-1:0]  z0;
    reg  [NBITS_Z-1:0]  z1;
    wire [NBITS_Z-1:0]  z2;

    assign z0 = mult_xtnd[NBITS_Z-1:0];
    assign z2 = acc_sat[NBITS_Z-1:0];

    always @(posedge clock_i or negedge reset_n_i)
        if (!reset_n_i)
            z1 <= 0;
        else begin
            z1 <= (OUTPUT_SELECT == 3'b100) ? z0 : z2;
        end    

    // Output mux
    assign z_o = (OUTPUT_SELECT == 3'h0) ?   z0 :
                 (OUTPUT_SELECT == 3'h1) ?   z2 :
                 (OUTPUT_SELECT == 3'h2) ?   z2 :
                 (OUTPUT_SELECT == 3'h3) ?   z2 :
                 (OUTPUT_SELECT == 3'h4) ?   z1 :
                 (OUTPUT_SELECT == 3'h5) ?   z1 :
                 (OUTPUT_SELECT == 3'h6) ?   z1 :
               /*(OUTPUT_SELECT == 3'h7) ?*/ z1;

    // B input delayed passthrough
    reg [NBITS_B-1:0] dly_b_o;

    always @(posedge clock_i or negedge reset_n_i)
        if (!reset_n_i)
            dly_b_o <= 0;
        else
            dly_b_o <= b_i;

endmodule

(* blackbox *) // TODO: add sim model
module dsp_t1_20x18x64 (
    input  [19:0] a_i,
    input  [17:0] b_i,
    input  [ 3:0] acc_fir_i,
    output [37:0] z_o,
    output [17:0] dly_b_o,

    (* clkbuf_sink *)
    input         clock_i,
    input         reset_i,

    input  [1:0]  feedback_i,
    input         load_acc_i,
    input         unsigned_a_i,
    input         unsigned_b_i,

    input  [2:0]  output_select_i,
    input         saturate_enable_i,
    input  [5:0]  shift_right_i,
    input         round_i,
    input         subtract_i,
    input         register_inputs_i
);

    parameter [19:0] COEFF_0 = 20'd0;
    parameter [19:0] COEFF_1 = 20'd0;
    parameter [19:0] COEFF_2 = 20'd0;
    parameter [19:0] COEFF_3 = 20'd0;

endmodule

(* blackbox *) // TODO: add sim model
module dsp_t1_10x9x32 (
    input  [ 9:0] a_i,
    input  [ 8:0] b_i,
    input  [ 1:0] acc_fir_i,
    output [18:0] z_o,
    output [ 8:0] dly_b_o,

    (* clkbuf_sink *)
    input         clock_i,
    input         reset_i,

    input  [1:0]  feedback_i,
    input         load_acc_i,
    input         unsigned_a_i,
    input         unsigned_b_i,

    input  [2:0]  output_select_i,
    input         saturate_enable_i,
    input  [5:0]  shift_right_i,
    input         round_i,
    input         subtract_i,
    input         register_inputs_i
);

    parameter [9:0] COEFF_0 = 10'd0;
    parameter [9:0] COEFF_1 = 10'd0;
    parameter [9:0] COEFF_2 = 10'd0;
    parameter [9:0] COEFF_3 = 10'd0;

endmodule
