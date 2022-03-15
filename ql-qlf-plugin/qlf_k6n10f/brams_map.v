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

`define MODE_36 3'b011	// 36 or 32-bit
`define MODE_18 3'b010	// 18 or 16-bit
`define MODE_9  3'b001	// 9 or 8-bit
`define MODE_4  3'b100	// 4-bit
`define MODE_2  3'b110	// 32-bit
`define MODE_1  3'b101	// 32-bit

module \$__QLF_FACTOR_BRAM36_TDP (A1ADDR, A1DATA, A1EN, B1ADDR, B1DATA, B1EN, C1ADDR, C1DATA, C1EN, CLK1, CLK2, D1ADDR, D1DATA, D1EN);
	parameter CFG_ABITS = 10;
	parameter CFG_DBITS = 36;
	parameter CFG_ENABLE_B = 4;
	parameter CFG_ENABLE_D = 4;

	parameter CLKPOL2 = 1;
	parameter CLKPOL3 = 1;
	parameter [36863:0] INIT = 36864'bx;

	input CLK1;
	input CLK2;

	input [CFG_ABITS-1:0] A1ADDR;
	output [CFG_DBITS-1:0] A1DATA;
	input A1EN;

	input [CFG_ABITS-1:0] B1ADDR;
	input [CFG_DBITS-1:0] B1DATA;
	input [CFG_ENABLE_B-1:0] B1EN;

	input [CFG_ABITS-1:0] C1ADDR;
	output [CFG_DBITS-1:0] C1DATA;
	input C1EN;

	input [CFG_ABITS-1:0] D1ADDR;
	input [CFG_DBITS-1:0] D1DATA;
	input [CFG_ENABLE_B-1:0] D1EN;

	wire FLUSH1;
	wire FLUSH2;
	wire SPLIT;

	wire [14:CFG_ABITS] A1ADDR_CMPL = {15-CFG_ABITS{1'b0}};
	wire [14:CFG_ABITS] B1ADDR_CMPL = {15-CFG_ABITS{1'b0}};
	wire [14:CFG_ABITS] C1ADDR_CMPL = {15-CFG_ABITS{1'b0}};
	wire [14:CFG_ABITS] D1ADDR_CMPL = {15-CFG_ABITS{1'b0}};

	wire [14:0] A1ADDR_TOTAL = {A1ADDR_CMPL, A1ADDR};
	wire [14:0] B1ADDR_TOTAL = {B1ADDR_CMPL, B1ADDR};
	wire [14:0] C1ADDR_TOTAL = {C1ADDR_CMPL, C1ADDR};
	wire [14:0] D1ADDR_TOTAL = {D1ADDR_CMPL, D1ADDR};

	wire [35:CFG_DBITS] A1DATA_CMPL;
	wire [35:CFG_DBITS] C1DATA_CMPL;

	wire [35:0] A1DATA_TOTAL = {A1DATA_CMPL, A1DATA};
	wire [35:0] C1DATA_TOTAL = {C1DATA_CMPL, C1DATA};

	wire [14:0] PORT_A_ADDR;
	wire [14:0] PORT_B_ADDR;

	case (CFG_DBITS)
		1: begin
			assign PORT_A_ADDR = A1EN ? A1ADDR_TOTAL : (B1EN ? B1ADDR_TOTAL : 15'd0);
			assign PORT_B_ADDR = C1EN ? C1ADDR_TOTAL : (D1EN ? D1ADDR_TOTAL : 15'd0);
            defparam _TECHMAP_REPLACE_.MODE_BITS = { 1'b0,
                11'd10, 11'd10, 4'd0, `MODE_1, `MODE_1, `MODE_1, `MODE_1, 1'd0,
                12'd10, 12'd10, 4'd0, `MODE_1, `MODE_1, `MODE_1, `MODE_1, 1'd0
            };
		end

		2: begin
			assign PORT_A_ADDR = A1EN ? (A1ADDR_TOTAL << 1) : (B1EN ? (B1ADDR_TOTAL << 1) : 15'd0);
			assign PORT_B_ADDR = C1EN ? (C1ADDR_TOTAL << 1) : (D1EN ? (D1ADDR_TOTAL << 1) : 15'd0);
            defparam _TECHMAP_REPLACE_.MODE_BITS = { 1'b0,
                11'd10, 11'd10, 4'd0, `MODE_2, `MODE_2, `MODE_2, `MODE_2, 1'd0,
                12'd10, 12'd10, 4'd0, `MODE_2, `MODE_2, `MODE_2, `MODE_2, 1'd0
            };
		end

		4: begin
			assign PORT_A_ADDR = A1EN ? (A1ADDR_TOTAL << 2) : (B1EN ? (B1ADDR_TOTAL << 2) : 15'd0);
			assign PORT_B_ADDR = C1EN ? (C1ADDR_TOTAL << 2) : (D1EN ? (D1ADDR_TOTAL << 2) : 15'd0);
            defparam _TECHMAP_REPLACE_.MODE_BITS = { 1'b0,
                11'd10, 11'd10, 4'd0, `MODE_4, `MODE_4, `MODE_4, `MODE_4, 1'd0,
                12'd10, 12'd10, 4'd0, `MODE_4, `MODE_4, `MODE_4, `MODE_4, 1'd0
            };
		end

		8, 9: begin
			assign PORT_A_ADDR = A1EN ? (A1ADDR_TOTAL << 3) : (B1EN ? (B1ADDR_TOTAL << 3) : 15'd0);
			assign PORT_B_ADDR = C1EN ? (C1ADDR_TOTAL << 3) : (D1EN ? (D1ADDR_TOTAL << 3) : 15'd0);
            defparam _TECHMAP_REPLACE_.MODE_BITS = { 1'b0,
                11'd10, 11'd10, 4'd0, `MODE_9, `MODE_9, `MODE_9, `MODE_9, 1'd0,
                12'd10, 12'd10, 4'd0, `MODE_9, `MODE_9, `MODE_9, `MODE_9, 1'd0
            };
		end

		16, 18: begin
			assign PORT_A_ADDR = A1EN ? (A1ADDR_TOTAL << 4) : (B1EN ? (B1ADDR_TOTAL << 4) : 15'd0);
			assign PORT_B_ADDR = C1EN ? (C1ADDR_TOTAL << 4) : (D1EN ? (D1ADDR_TOTAL << 4) : 15'd0);
            defparam _TECHMAP_REPLACE_.MODE_BITS = { 1'b0,
                11'd10, 11'd10, 4'd0, `MODE_18, `MODE_18, `MODE_18, `MODE_18, 1'd0,
                12'd10, 12'd10, 4'd0, `MODE_18, `MODE_18, `MODE_18, `MODE_18, 1'd0
            };
		end

		32, 36: begin
			assign PORT_A_ADDR = A1EN ? (A1ADDR_TOTAL << 5) : (B1EN ? (B1ADDR_TOTAL << 5) : 15'd0);
			assign PORT_B_ADDR = C1EN ? (C1ADDR_TOTAL << 5) : (D1EN ? (D1ADDR_TOTAL << 5) : 15'd0);
            defparam _TECHMAP_REPLACE_.MODE_BITS = { 1'b0,
                11'd10, 11'd10, 4'd0, `MODE_36, `MODE_36, `MODE_36, `MODE_36, 1'd0,
                12'd10, 12'd10, 4'd0, `MODE_36, `MODE_36, `MODE_36, `MODE_36, 1'd0
            };
		end
		default: begin
			assign PORT_A_ADDR = A1EN ? A1ADDR_TOTAL : (B1EN ? B1ADDR_TOTAL : 15'd0);
			assign PORT_B_ADDR = C1EN ? C1ADDR_TOTAL : (D1EN ? D1ADDR_TOTAL : 15'd0);
            defparam _TECHMAP_REPLACE_.MODE_BITS = { 1'b0,
                11'd10, 11'd10, 4'd0, `MODE_36, `MODE_36, `MODE_36, `MODE_36, 1'd0,
                12'd10, 12'd10, 4'd0, `MODE_36, `MODE_36, `MODE_36, `MODE_36, 1'd0
            };
		end
	endcase


	assign SPLIT = 1'b0;
	assign FLUSH1 = 1'b0;
	assign FLUSH2 = 1'b0;

	TDP36K _TECHMAP_REPLACE_ (
		.RESET_ni(1'b1),
		.WDATA_A1_i(B1DATA[17:0]),
		.WDATA_A2_i(B1DATA[35:18]),
		.RDATA_A1_o(A1DATA_TOTAL[17:0]),
		.RDATA_A2_o(A1DATA_TOTAL[35:18]),
		.ADDR_A1_i(PORT_A_ADDR),
		.ADDR_A2_i(PORT_A_ADDR),
		.CLK_A1_i(CLK1),
		.CLK_A2_i(CLK1),
		.REN_A1_i(A1EN),
		.REN_A2_i(A1EN),
		.WEN_A1_i(B1EN[0]),
		.WEN_A2_i(B1EN[0]),
		.BE_A1_i({B1EN[1],B1EN[0]}),
		.BE_A2_i({B1EN[3],B1EN[2]}),

		.WDATA_B1_i(D1DATA[17:0]),
		.WDATA_B2_i(D1DATA[35:18]),
		.RDATA_B1_o(C1DATA_TOTAL[17:0]),
		.RDATA_B2_o(C1DATA_TOTAL[35:18]),
		.ADDR_B1_i(PORT_B_ADDR),
		.ADDR_B2_i(PORT_B_ADDR),
		.CLK_B1_i(CLK2),
		.CLK_B2_i(CLK2),
		.REN_B1_i(C1EN),
		.REN_B2_i(C1EN),
		.WEN_B1_i(D1EN[0]),
		.WEN_B2_i(D1EN[0]),
		.BE_B1_i({D1EN[1],D1EN[0]}),
		.BE_B2_i({D1EN[3],D1EN[2]}),

		.FLUSH1_i(FLUSH1),
		.FLUSH2_i(FLUSH2)
	);
endmodule

// ------------------------------------------------------------------------

module \$__QLF_FACTOR_BRAM18_TDP (CLK2, CLK3, A1ADDR, A1DATA, A1EN, B1ADDR, B1DATA, B1EN);
	parameter CFG_ABITS = 10;
	parameter CFG_DBITS = 18;
	parameter CFG_ENABLE_B = 2;

	parameter CLKPOL2 = 1;
	parameter CLKPOL3 = 1;
	parameter [18431:0] INIT = 18432'bx;

	input CLK2;
	input CLK3;

	input [CFG_ABITS-1:0] A1ADDR;
	output [CFG_DBITS-1:0] A1DATA;
	input A1EN;

	input [CFG_ABITS-1:0] B1ADDR;
	input [CFG_DBITS-1:0] B1DATA;
	input [CFG_ENABLE_B-1:0] B1EN;

	wire [13:0] A1ADDR_14;
	wire [13:0] B1ADDR_14;
	//wire [3:0] B1EN_4 = B1EN;

	wire [1:0] DIP, DOP;
	wire [15:0] DI, DO;

	wire [15:0] DOBDO;
	wire [1:0] DOPBDOP;

	assign A1DATA = { DOP[1], DO[15: 8], DOP[0], DO[ 7: 0] };
	assign { DIP[1], DI[15: 8], DIP[0], DI[ 7: 0] } = B1DATA;
        
        assign A1ADDR_14[13:CFG_ABITS]  = 0;
        assign A1ADDR_14[CFG_ABITS-1:0] = A1ADDR;
        assign B1ADDR_14[13:CFG_ABITS]  = 0;
        assign B1ADDR_14[CFG_ABITS-1:0] = B1ADDR;

	/*if (CFG_DBITS == 1) begin
	  assign WRITEDATAWIDTHB = 3'b000;
	  assign READDATAWIDTHA = 3'b000;
	end else if (CFG_DBITS == 2) begin
          assign WRITEDATAWIDTHB = 3'b001;
          assign READDATAWIDTHA = 3'b001;
        end else if (CFG_DBITS > 2 && CFG_DBITS <= 4) begin
          assign WRITEDATAWIDTHB = 3'b010;
          assign READDATAWIDTHA = 3'b010;
        end else if (CFG_DBITS > 4 && CFG_DBITS <= 9) begin
          assign WRITEDATAWIDTHB = 3'b011;
          assign READDATAWIDTHA = 3'b011;
        end else if (CFG_DBITS > 9 && CFG_DBITS <= 18) begin
          //assign WRITEDATAWIDTHB = 3'b100;
          assign READDATAWIDTHA = 3'b100;
	end*/
	generate if (CFG_DBITS > 8) begin
		TDP_BRAM18 #(
			//`include "brams_init_18.vh"
                        .READ_WIDTH_A(CFG_DBITS),
                        .READ_WIDTH_B(CFG_DBITS),
                        .WRITE_WIDTH_A(CFG_DBITS),
                        .WRITE_WIDTH_B(CFG_DBITS),
		) _TECHMAP_REPLACE_ (
			.WRITEDATAA(16'hFFFF),
			.WRITEDATAAP(2'b11),
			.READDATAA(DO[15:0]),
			.READDATAAP(DOP[2:0]),
			.ADDRA(A1ADDR_14),
			.CLOCKA(CLK2),
			.READENABLEA(A1EN),
			.WRITEENABLEA(1'b0),
			.BYTEENABLEA(2'b0),
			//.WRITEDATAWIDTHA(3'b0),
			//.READDATAWIDTHA(READDATAWIDTHA),

			.WRITEDATAB(DI),
			.WRITEDATABP(DIP),
			.READDATAB(DOBDO),
			.READDATABP(DOPBDOP),
			.ADDRB(B1ADDR_14),
			.CLOCKB(CLK3),
			.READENABLEB(1'b0),
			.WRITEENABLEB(1'b1),
			.BYTEENABLEB(B1EN)
			//.WRITEDATAWIDTHB(WRITEDATAWIDTHB),
			//.READDATAWIDTHB(3'b0)
		);
	end else begin
		TDP_BRAM18 #(
			//`include "brams_init_16.vh"
		) _TECHMAP_REPLACE_ (
			.WRITEDATAA(16'hFFFF),
			.WRITEDATAAP(2'b11),
			.READDATAA(DO[15:0]),
			.READDATAAP(DOP[2:0]),
			.ADDRA(A1ADDR_14),
			.CLOCKA(CLK2),
			.READENABLEA(A1EN),
			.WRITEENABLEA(1'b0),
			.BYTEENABLEA(2'b0),
			//.WRITEDATAWIDTHA(3'b0),
		//	.READDATAWIDTHA(READDATAWIDTHA),

			.WRITEDATAB(DI),
			.WRITEDATABP(DIP),
			.READDATAB(DOBDO),
			.READDATABP(DOPBDOP),
			.ADDRB(B1ADDR_14),
			.CLOCKB(CLK3),
			.READENABLEB(1'b0),
			.WRITEENABLEB(1'b1),
			.BYTEENABLEB(B1EN)
			//.WRITEDATAWIDTHB(WRITEDATAWIDTHB),
			//.READDATAWIDTHB(3'b0)
		);
	end endgenerate
endmodule

module \$__QLF_FACTOR_BRAM36_SDP (CLK2, CLK3, A1ADDR, A1DATA, A1EN, B1ADDR, B1DATA, B1EN);
	parameter CFG_ABITS = 10;
	parameter CFG_DBITS = 36;
	parameter CFG_ENABLE_B = 4;

	parameter CLKPOL2 = 1;
	parameter CLKPOL3 = 1;
	parameter [36863:0] INIT = 36864'bx;

	localparam MODE_36  = 3'b111;	// 36 or 32-bit
	localparam MODE_18  = 3'b110;	// 18 or 16-bit
	localparam MODE_9   = 3'b101;	// 9 or 8-bit
	localparam MODE_4   = 3'b100;	// 4-bit
	localparam MODE_2   = 3'b010;	// 32-bit
	localparam MODE_1   = 3'b001;	// 32-bit

	input CLK2;
	input CLK3;

	input [CFG_ABITS-1:0] A1ADDR;
	output [CFG_DBITS-1:0] A1DATA;
	input A1EN;

	input [CFG_ABITS-1:0] B1ADDR;
	input [CFG_DBITS-1:0] B1DATA;
	input [CFG_ENABLE_B-1:0] B1EN;

	wire [14:0] A1ADDR_15;
	wire [14:0] B1ADDR_15;

	wire [35:0] DOBDO;

	wire [14:CFG_ABITS] A1ADDR_CMPL;
	wire [14:CFG_ABITS] B1ADDR_CMPL;
	wire [35:CFG_DBITS] A1DATA_CMPL;
	wire [35:CFG_DBITS] B1DATA_CMPL;

	wire [14:0] A1ADDR_TOTAL;
	wire [14:0] B1ADDR_TOTAL;
	wire [35:0] A1DATA_TOTAL;
	wire [35:0] B1DATA_TOTAL;

	wire FLUSH1;
	wire FLUSH2;

	assign A1ADDR_CMPL = {15-CFG_ABITS{1'b0}};
	assign B1ADDR_CMPL = {15-CFG_ABITS{1'b0}};

	assign A1ADDR_TOTAL = {A1ADDR_CMPL, A1ADDR};
	assign B1ADDR_TOTAL = {B1ADDR_CMPL, B1ADDR};

	assign A1DATA_TOTAL = {A1DATA_CMPL, A1DATA};
	assign B1DATA_TOTAL = {B1DATA_CMPL, B1DATA};

	case (CFG_DBITS)
		1: begin
			assign A1ADDR_15 = A1ADDR_TOTAL;
			assign B1ADDR_15 = B1ADDR_TOTAL;
            defparam _TECHMAP_REPLACE_.MODE_BITS = { 1'b0,
                11'd10, 11'd10, 4'd0, `MODE_1, `MODE_1, `MODE_1, `MODE_1, 1'd0,
                12'd10, 12'd10, 4'd0, `MODE_1, `MODE_1, `MODE_1, `MODE_1, 1'd0
            };
		end

		2: begin
			assign A1ADDR_15 = A1ADDR_TOTAL << 1;
			assign B1ADDR_15 = B1ADDR_TOTAL << 1;
            defparam _TECHMAP_REPLACE_.MODE_BITS = { 1'b0,
                11'd10, 11'd10, 4'd0, `MODE_2, `MODE_2, `MODE_2, `MODE_2, 1'd0,
                12'd10, 12'd10, 4'd0, `MODE_2, `MODE_2, `MODE_2, `MODE_2, 1'd0
            };
		end

		4: begin
			assign A1ADDR_15 = A1ADDR_TOTAL << 2;
			assign B1ADDR_15 = B1ADDR_TOTAL << 2;
            defparam _TECHMAP_REPLACE_.MODE_BITS = { 1'b0,
                11'd10, 11'd10, 4'd0, `MODE_4, `MODE_4, `MODE_4, `MODE_4, 1'd0,
                12'd10, 12'd10, 4'd0, `MODE_4, `MODE_4, `MODE_4, `MODE_4, 1'd0
            };
		end
		8, 9: begin
			assign A1ADDR_15 = A1ADDR_TOTAL << 3;
			assign B1ADDR_15 = B1ADDR_TOTAL << 3;
            defparam _TECHMAP_REPLACE_.MODE_BITS = { 1'b0,
                11'd10, 11'd10, 4'd0, `MODE_9, `MODE_9, `MODE_9, `MODE_9, 1'd0,
                12'd10, 12'd10, 4'd0, `MODE_9, `MODE_9, `MODE_9, `MODE_9, 1'd0
            };
		end

		16, 18: begin
			assign A1ADDR_15 = A1ADDR_TOTAL << 4;
			assign B1ADDR_15 = B1ADDR_TOTAL << 4;
            defparam _TECHMAP_REPLACE_.MODE_BITS = { 1'b0,
                11'd10, 11'd10, 4'd0, `MODE_18, `MODE_18, `MODE_18, `MODE_18, 1'd0,
                12'd10, 12'd10, 4'd0, `MODE_18, `MODE_18, `MODE_18, `MODE_18, 1'd0
            };
		end
		32, 36: begin
			assign A1ADDR_15 = A1ADDR_TOTAL << 5;
			assign B1ADDR_15 = B1ADDR_TOTAL << 5;
            defparam _TECHMAP_REPLACE_.MODE_BITS = { 1'b0,
                11'd10, 11'd10, 4'd0, `MODE_36, `MODE_36, `MODE_36, `MODE_36, 1'd0,
                12'd10, 12'd10, 4'd0, `MODE_36, `MODE_36, `MODE_36, `MODE_36, 1'd0
            };
		end
		default: begin
			assign A1ADDR_15 = A1ADDR_TOTAL;
			assign B1ADDR_15 = B1ADDR_TOTAL;
            defparam _TECHMAP_REPLACE_.MODE_BITS = { 1'b0,
                11'd10, 11'd10, 4'd0, `MODE_36, `MODE_36, `MODE_36, `MODE_36, 1'd0,
                12'd10, 12'd10, 4'd0, `MODE_36, `MODE_36, `MODE_36, `MODE_36, 1'd0
            };
		end
	endcase


	assign FLUSH1 = 1'b0;
	assign FLUSH2 = 1'b0;

	TDP36K _TECHMAP_REPLACE_ (
		.RESET_ni(1'b1),
		.WDATA_A1_i(18'h3FFFF),
		.WDATA_A2_i(18'h3FFFF),
		.RDATA_A1_o(A1DATA_TOTAL[17:0]),
		.RDATA_A2_o(A1DATA_TOTAL[35:18]),
		.ADDR_A1_i(A1ADDR_15),
		.ADDR_A2_i(A1ADDR_15),
		.CLK_A1_i(CLK2),
		.CLK_A2_i(CLK2),
		.REN_A1_i(A1EN),
		.REN_A2_i(A1EN),
		.WEN_A1_i(1'b0),
		.WEN_A2_i(1'b0),
		.BE_A1_i({A1EN, A1EN}),
		.BE_A2_i({A1EN, A1EN}),

		.WDATA_B1_i(B1DATA[17:0]),
		.WDATA_B2_i(B1DATA[35:18]),
		.RDATA_B1_o(DOBDO[17:0]),
		.RDATA_B2_o(DOBDO[35:18]),
		.ADDR_B1_i(B1ADDR_15),
		.ADDR_B2_i(B1ADDR_15),
		.CLK_B1_i(CLK3),
		.CLK_B2_i(CLK3),
		.REN_B1_i(1'b0),
		.REN_B2_i(1'b0),
		.WEN_B1_i(B1EN[0]),
		.WEN_B2_i(B1EN[0]),
		.BE_B1_i(B1EN[1:0]),
		.BE_B2_i(B1EN[3:2]),

		.FLUSH1_i(FLUSH1),
		.FLUSH2_i(FLUSH2)
	);
endmodule

