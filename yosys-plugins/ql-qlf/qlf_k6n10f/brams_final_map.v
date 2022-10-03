// Copyright (C) 2020-2021  The SymbiFlow Authors.
//
// Use of this source code is governed by a ISC-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/ISC
//
// SPDX-License-Identifier:ISC

`define MODE_36 3'b011	// 36 or 32-bit
`define MODE_18 3'b010	// 18 or 16-bit
`define MODE_9  3'b001	// 9 or 8-bit
`define MODE_4  3'b100	// 4-bit
`define MODE_2  3'b110	// 32-bit
`define MODE_1  3'b101	// 32-bit

module BRAM2x18_TDP (A1ADDR, A1DATA, A1EN, B1ADDR, B1DATA, B1EN, C1ADDR, C1DATA, C1EN, CLK1, CLK2, CLK3, CLK4, D1ADDR, D1DATA, D1EN, E1ADDR, E1DATA, E1EN, F1ADDR, F1DATA, F1EN, G1ADDR, G1DATA, G1EN, H1ADDR, H1DATA, H1EN);
	parameter CFG_ABITS = 11;
	parameter CFG_DBITS = 18;
	parameter CFG_ENABLE_B = 4;
	parameter CFG_ENABLE_D = 4;
	parameter CFG_ENABLE_F = 4;
	parameter CFG_ENABLE_H = 4;

	parameter CLKPOL2 = 1;
	parameter CLKPOL3 = 1;
	parameter [18431:0] INIT0 = 18432'bx;
	parameter [18431:0] INIT1 = 18432'bx;

	input CLK1;
	input CLK2;
	input CLK3;
	input CLK4;

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
	input [CFG_ENABLE_D-1:0] D1EN;

	input [CFG_ABITS-1:0] E1ADDR;
	output [CFG_DBITS-1:0] E1DATA;
	input E1EN;

	input [CFG_ABITS-1:0] F1ADDR;
	input [CFG_DBITS-1:0] F1DATA;
	input [CFG_ENABLE_F-1:0] F1EN;

	input [CFG_ABITS-1:0] G1ADDR;
	output [CFG_DBITS-1:0] G1DATA;
	input G1EN;

	input [CFG_ABITS-1:0] H1ADDR;
	input [CFG_DBITS-1:0] H1DATA;
	input [CFG_ENABLE_H-1:0] H1EN;

	wire FLUSH1;
	wire FLUSH2;

	wire [13:CFG_ABITS] A1ADDR_CMPL = {14-CFG_ABITS{1'b0}};
	wire [13:CFG_ABITS] B1ADDR_CMPL = {14-CFG_ABITS{1'b0}};
	wire [13:CFG_ABITS] C1ADDR_CMPL = {14-CFG_ABITS{1'b0}};
	wire [13:CFG_ABITS] D1ADDR_CMPL = {14-CFG_ABITS{1'b0}};
	wire [13:CFG_ABITS] E1ADDR_CMPL = {14-CFG_ABITS{1'b0}};
	wire [13:CFG_ABITS] F1ADDR_CMPL = {14-CFG_ABITS{1'b0}};
	wire [13:CFG_ABITS] G1ADDR_CMPL = {14-CFG_ABITS{1'b0}};
	wire [13:CFG_ABITS] H1ADDR_CMPL = {14-CFG_ABITS{1'b0}};

	wire [13:0] A1ADDR_TOTAL = {A1ADDR_CMPL, A1ADDR};
	wire [13:0] B1ADDR_TOTAL = {B1ADDR_CMPL, B1ADDR};
	wire [13:0] C1ADDR_TOTAL = {C1ADDR_CMPL, C1ADDR};
	wire [13:0] D1ADDR_TOTAL = {D1ADDR_CMPL, D1ADDR};
	wire [13:0] E1ADDR_TOTAL = {E1ADDR_CMPL, E1ADDR};
	wire [13:0] F1ADDR_TOTAL = {F1ADDR_CMPL, F1ADDR};
	wire [13:0] G1ADDR_TOTAL = {G1ADDR_CMPL, G1ADDR};
	wire [13:0] H1ADDR_TOTAL = {H1ADDR_CMPL, H1ADDR};

	wire [17:CFG_DBITS] A1_RDATA_CMPL;
	wire [17:CFG_DBITS] C1_RDATA_CMPL;
	wire [17:CFG_DBITS] E1_RDATA_CMPL;
	wire [17:CFG_DBITS] G1_RDATA_CMPL;

	wire [17:CFG_DBITS] B1_WDATA_CMPL;
	wire [17:CFG_DBITS] D1_WDATA_CMPL;
	wire [17:CFG_DBITS] F1_WDATA_CMPL;
	wire [17:CFG_DBITS] H1_WDATA_CMPL;

	wire [13:0] PORT_A1_ADDR;
	wire [13:0] PORT_A2_ADDR;
	wire [13:0] PORT_B1_ADDR;
	wire [13:0] PORT_B2_ADDR;

	case (CFG_DBITS)
		1: begin
			assign PORT_A1_ADDR = A1EN ? A1ADDR_TOTAL : (B1EN ? B1ADDR_TOTAL : 14'd0);
			assign PORT_B1_ADDR = C1EN ? C1ADDR_TOTAL : (D1EN ? D1ADDR_TOTAL : 14'd0);
			assign PORT_A2_ADDR = E1EN ? E1ADDR_TOTAL : (F1EN ? F1ADDR_TOTAL : 14'd0);
			assign PORT_B2_ADDR = G1EN ? G1ADDR_TOTAL : (H1EN ? H1ADDR_TOTAL : 14'd0);
			defparam _TECHMAP_REPLACE_.MODE_BITS = { 1'b1,
				11'd10, 11'd10, 4'd0, `MODE_1, `MODE_1, `MODE_1, `MODE_1, 1'd0,
				12'd10, 12'd10, 4'd0, `MODE_1, `MODE_1, `MODE_1, `MODE_1, 1'd0
			};
		end

		2: begin
			assign PORT_A1_ADDR = A1EN ? (A1ADDR_TOTAL << 1) : (B1EN ? (B1ADDR_TOTAL << 1) : 14'd0);
			assign PORT_B1_ADDR = C1EN ? (C1ADDR_TOTAL << 1) : (D1EN ? (D1ADDR_TOTAL << 1) : 14'd0);
			assign PORT_A2_ADDR = E1EN ? (E1ADDR_TOTAL << 1) : (F1EN ? (F1ADDR_TOTAL << 1) : 14'd0);
			assign PORT_B2_ADDR = G1EN ? (G1ADDR_TOTAL << 1) : (H1EN ? (H1ADDR_TOTAL << 1) : 14'd0);
			defparam _TECHMAP_REPLACE_.MODE_BITS = { 1'b1,
				11'd10, 11'd10, 4'd0, `MODE_2, `MODE_2, `MODE_2, `MODE_2, 1'd0,
				12'd10, 12'd10, 4'd0, `MODE_2, `MODE_2, `MODE_2, `MODE_2, 1'd0
			};
		end

		4: begin
			assign PORT_A1_ADDR = A1EN ? (A1ADDR_TOTAL << 2) : (B1EN ? (B1ADDR_TOTAL << 2) : 14'd0);
			assign PORT_B1_ADDR = C1EN ? (C1ADDR_TOTAL << 2) : (D1EN ? (D1ADDR_TOTAL << 2) : 14'd0);
			assign PORT_A2_ADDR = E1EN ? (E1ADDR_TOTAL << 2) : (F1EN ? (F1ADDR_TOTAL << 2) : 14'd0);
			assign PORT_B2_ADDR = G1EN ? (G1ADDR_TOTAL << 2) : (H1EN ? (H1ADDR_TOTAL << 2) : 14'd0);
			defparam _TECHMAP_REPLACE_.MODE_BITS = { 1'b1,
				11'd10, 11'd10, 4'd0, `MODE_4, `MODE_4, `MODE_4, `MODE_4, 1'd0,
				12'd10, 12'd10, 4'd0, `MODE_4, `MODE_4, `MODE_4, `MODE_4, 1'd0
			};
		end

		8, 9: begin
			assign PORT_A1_ADDR = A1EN ? (A1ADDR_TOTAL << 3) : (B1EN ? (B1ADDR_TOTAL << 3) : 14'd0);
			assign PORT_B1_ADDR = C1EN ? (C1ADDR_TOTAL << 3) : (D1EN ? (D1ADDR_TOTAL << 3) : 14'd0);
			assign PORT_A2_ADDR = E1EN ? (E1ADDR_TOTAL << 3) : (F1EN ? (F1ADDR_TOTAL << 3) : 14'd0);
			assign PORT_B2_ADDR = G1EN ? (G1ADDR_TOTAL << 3) : (H1EN ? (H1ADDR_TOTAL << 3) : 14'd0);
			defparam _TECHMAP_REPLACE_.MODE_BITS = { 1'b1,
				11'd10, 11'd10, 4'd0, `MODE_9, `MODE_9, `MODE_9, `MODE_9, 1'd0,
				12'd10, 12'd10, 4'd0, `MODE_9, `MODE_9, `MODE_9, `MODE_9, 1'd0
			};
		end

		16, 18: begin
			assign PORT_A1_ADDR = A1EN ? (A1ADDR_TOTAL << 4) : (B1EN ? (B1ADDR_TOTAL << 4) : 14'd0);
			assign PORT_B1_ADDR = C1EN ? (C1ADDR_TOTAL << 4) : (D1EN ? (D1ADDR_TOTAL << 4) : 14'd0);
			assign PORT_A2_ADDR = E1EN ? (E1ADDR_TOTAL << 4) : (F1EN ? (F1ADDR_TOTAL << 4) : 14'd0);
			assign PORT_B2_ADDR = G1EN ? (G1ADDR_TOTAL << 4) : (H1EN ? (H1ADDR_TOTAL << 4) : 14'd0);
			defparam _TECHMAP_REPLACE_.MODE_BITS = { 1'b1,
				11'd10, 11'd10, 4'd0, `MODE_18, `MODE_18, `MODE_18, `MODE_18, 1'd0,
				12'd10, 12'd10, 4'd0, `MODE_18, `MODE_18, `MODE_18, `MODE_18, 1'd0
			};
		end

		default: begin
			assign PORT_A1_ADDR = A1EN ? A1ADDR_TOTAL : (B1EN ? B1ADDR_TOTAL : 14'd0);
			assign PORT_B1_ADDR = C1EN ? C1ADDR_TOTAL : (D1EN ? D1ADDR_TOTAL : 14'd0);
			assign PORT_A2_ADDR = E1EN ? E1ADDR_TOTAL : (F1EN ? F1ADDR_TOTAL : 14'd0);
			assign PORT_B2_ADDR = G1EN ? G1ADDR_TOTAL : (H1EN ? H1ADDR_TOTAL : 14'd0);
			defparam _TECHMAP_REPLACE_.MODE_BITS = { 1'b1,
				11'd10, 11'd10, 4'd0, `MODE_36, `MODE_36, `MODE_36, `MODE_36, 1'd0,
				12'd10, 12'd10, 4'd0, `MODE_36, `MODE_36, `MODE_36, `MODE_36, 1'd0
			};
		end
	endcase

	assign FLUSH1 = 1'b0;
	assign FLUSH2 = 1'b0;

	wire [17:0] PORT_A1_RDATA;
	wire [17:0] PORT_B1_RDATA;
	wire [17:0] PORT_A2_RDATA;
	wire [17:0] PORT_B2_RDATA;

	wire [17:0] PORT_A1_WDATA;
	wire [17:0] PORT_B1_WDATA;
	wire [17:0] PORT_A2_WDATA;
	wire [17:0] PORT_B2_WDATA;

	// Assign read/write data - handle special case for 9bit mode
	// parity bit for 9bit mode is placed in R/W port on bit #16
	case (CFG_DBITS)
		9: begin
			assign A1DATA = {PORT_A1_RDATA[16], PORT_A1_RDATA[7:0]};
			assign C1DATA = {PORT_B1_RDATA[16], PORT_B1_RDATA[7:0]};
			assign E1DATA = {PORT_A2_RDATA[16], PORT_A2_RDATA[7:0]};
			assign G1DATA = {PORT_B2_RDATA[16], PORT_B2_RDATA[7:0]};
			assign PORT_A1_WDATA = {B1_WDATA_CMPL[17], B1DATA[8], B1_WDATA_CMPL[16:9], B1DATA[7:0]};
			assign PORT_B1_WDATA = {D1_WDATA_CMPL[17], D1DATA[8], D1_WDATA_CMPL[16:9], D1DATA[7:0]};
			assign PORT_A2_WDATA = {F1_WDATA_CMPL[17], F1DATA[8], F1_WDATA_CMPL[16:9], F1DATA[7:0]};
			assign PORT_B2_WDATA = {H1_WDATA_CMPL[17], H1DATA[8], H1_WDATA_CMPL[16:9], H1DATA[7:0]};
		end
		default: begin
			assign A1DATA = PORT_A1_RDATA[CFG_DBITS-1:0];
			assign C1DATA = PORT_B1_RDATA[CFG_DBITS-1:0];
			assign E1DATA = PORT_A2_RDATA[CFG_DBITS-1:0];
			assign G1DATA = PORT_B2_RDATA[CFG_DBITS-1:0];
			assign PORT_A1_WDATA = {B1_WDATA_CMPL, B1DATA};
			assign PORT_B1_WDATA = {D1_WDATA_CMPL, D1DATA};
			assign PORT_A2_WDATA = {F1_WDATA_CMPL, F1DATA};
			assign PORT_B2_WDATA = {H1_WDATA_CMPL, H1DATA};

		end
	endcase

	wire PORT_A1_CLK = CLK1;
	wire PORT_A2_CLK = CLK3;
	wire PORT_B1_CLK = CLK2;
	wire PORT_B2_CLK = CLK4;

	wire PORT_A1_REN = A1EN;
	wire PORT_A1_WEN = B1EN[0];
	wire [CFG_ENABLE_B-1:0] PORT_A1_BE = {B1EN[1],B1EN[0]};

	wire PORT_A2_REN = E1EN;
	wire PORT_A2_WEN = F1EN[0];
	wire [CFG_ENABLE_F-1:0] PORT_A2_BE = {F1EN[1],F1EN[0]};

	wire PORT_B1_REN = C1EN;
	wire PORT_B1_WEN = D1EN[0];
	wire [CFG_ENABLE_D-1:0] PORT_B1_BE = {D1EN[1],D1EN[0]};

	wire PORT_B2_REN = G1EN;
	wire PORT_B2_WEN = H1EN[0];
	wire [CFG_ENABLE_H-1:0] PORT_B2_BE = {H1EN[1],H1EN[0]};

	TDP36K  _TECHMAP_REPLACE_ (
		.WDATA_A1_i(PORT_A1_WDATA),
		.RDATA_A1_o(PORT_A1_RDATA),
		.ADDR_A1_i(PORT_A1_ADDR),
		.CLK_A1_i(PORT_A1_CLK),
		.REN_A1_i(PORT_A1_REN),
		.WEN_A1_i(PORT_A1_WEN),
		.BE_A1_i(PORT_A1_BE),

		.WDATA_A2_i(PORT_A2_WDATA),
		.RDATA_A2_o(PORT_A2_RDATA),
		.ADDR_A2_i(PORT_A2_ADDR),
		.CLK_A2_i(PORT_A2_CLK),
		.REN_A2_i(PORT_A2_REN),
		.WEN_A2_i(PORT_A2_WEN),
		.BE_A2_i(PORT_A2_BE),

		.WDATA_B1_i(PORT_B1_WDATA),
		.RDATA_B1_o(PORT_B1_RDATA),
		.ADDR_B1_i(PORT_B1_ADDR),
		.CLK_B1_i(PORT_B1_CLK),
		.REN_B1_i(PORT_B1_REN),
		.WEN_B1_i(PORT_B1_WEN),
		.BE_B1_i(PORT_B1_BE),

		.WDATA_B2_i(PORT_B2_WDATA),
		.RDATA_B2_o(PORT_B2_RDATA),
		.ADDR_B2_i(PORT_B2_ADDR),
		.CLK_B2_i(PORT_B2_CLK),
		.REN_B2_i(PORT_B2_REN),
		.WEN_B2_i(PORT_B2_WEN),
		.BE_B2_i(PORT_B2_BE),

		.FLUSH1_i(FLUSH1),
		.FLUSH2_i(FLUSH2)
	);
endmodule

module BRAM2x18_SDP (A1ADDR, A1DATA, A1EN, B1ADDR, B1DATA, B1EN, C1ADDR, C1DATA, C1EN, CLK1, CLK2, D1ADDR, D1DATA, D1EN);
	parameter CFG_ABITS = 11;
	parameter CFG_DBITS = 18;
	parameter CFG_ENABLE_B = 4;
	parameter CFG_ENABLE_D = 4;

	parameter CLKPOL2 = 1;
	parameter CLKPOL3 = 1;
	parameter [18431:0] INIT0 = 18432'bx;
	parameter [18431:0] INIT1 = 18432'bx;

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
	input [CFG_ENABLE_D-1:0] D1EN;

	wire FLUSH1;
	wire FLUSH2;

	wire [13:CFG_ABITS] A1ADDR_CMPL = {14-CFG_ABITS{1'b0}};
	wire [13:CFG_ABITS] B1ADDR_CMPL = {14-CFG_ABITS{1'b0}};
	wire [13:CFG_ABITS] C1ADDR_CMPL = {14-CFG_ABITS{1'b0}};
	wire [13:CFG_ABITS] D1ADDR_CMPL = {14-CFG_ABITS{1'b0}};

	wire [13:0] A1ADDR_TOTAL = {A1ADDR_CMPL, A1ADDR};
	wire [13:0] B1ADDR_TOTAL = {B1ADDR_CMPL, B1ADDR};
	wire [13:0] C1ADDR_TOTAL = {C1ADDR_CMPL, C1ADDR};
	wire [13:0] D1ADDR_TOTAL = {D1ADDR_CMPL, D1ADDR};

	wire [17:CFG_DBITS] A1_RDATA_CMPL;
	wire [17:CFG_DBITS] C1_RDATA_CMPL;

	wire [17:CFG_DBITS] B1_WDATA_CMPL;
	wire [17:CFG_DBITS] D1_WDATA_CMPL;

	wire [13:0] PORT_A1_ADDR;
	wire [13:0] PORT_A2_ADDR;
	wire [13:0] PORT_B1_ADDR;
	wire [13:0] PORT_B2_ADDR;

	case (CFG_DBITS)
		1: begin
			assign PORT_A1_ADDR = A1ADDR_TOTAL;
			assign PORT_B1_ADDR = B1ADDR_TOTAL;
			assign PORT_A2_ADDR = C1ADDR_TOTAL;
			assign PORT_B2_ADDR = D1ADDR_TOTAL;
			defparam _TECHMAP_REPLACE_.MODE_BITS = { 1'b1,
				11'd10, 11'd10, 4'd0, `MODE_1, `MODE_1, `MODE_1, `MODE_1, 1'd0,
				12'd10, 12'd10, 4'd0, `MODE_1, `MODE_1, `MODE_1, `MODE_1, 1'd0
			};
		end

		2: begin
			assign PORT_A1_ADDR = A1ADDR_TOTAL << 1;
			assign PORT_B1_ADDR = B1ADDR_TOTAL << 1;
			assign PORT_A2_ADDR = C1ADDR_TOTAL << 1;
			assign PORT_B2_ADDR = D1ADDR_TOTAL << 1;
			defparam _TECHMAP_REPLACE_.MODE_BITS = { 1'b1,
				11'd10, 11'd10, 4'd0, `MODE_2, `MODE_2, `MODE_2, `MODE_2, 1'd0,
				12'd10, 12'd10, 4'd0, `MODE_2, `MODE_2, `MODE_2, `MODE_2, 1'd0
			};
		end

		4: begin
			assign PORT_A1_ADDR = A1ADDR_TOTAL << 2;
			assign PORT_B1_ADDR = B1ADDR_TOTAL << 2;
			assign PORT_A2_ADDR = C1ADDR_TOTAL << 2;
			assign PORT_B2_ADDR = D1ADDR_TOTAL << 2;
			defparam _TECHMAP_REPLACE_.MODE_BITS = { 1'b1,
				11'd10, 11'd10, 4'd0, `MODE_4, `MODE_4, `MODE_4, `MODE_4, 1'd0,
				12'd10, 12'd10, 4'd0, `MODE_4, `MODE_4, `MODE_4, `MODE_4, 1'd0
			};
		end

		8, 9: begin
			assign PORT_A1_ADDR = A1ADDR_TOTAL << 3;
			assign PORT_B1_ADDR = B1ADDR_TOTAL << 3;
			assign PORT_A2_ADDR = C1ADDR_TOTAL << 3;
			assign PORT_B2_ADDR = D1ADDR_TOTAL << 3;
			defparam _TECHMAP_REPLACE_.MODE_BITS = { 1'b1,
				11'd10, 11'd10, 4'd0, `MODE_9, `MODE_9, `MODE_9, `MODE_9, 1'd0,
				12'd10, 12'd10, 4'd0, `MODE_9, `MODE_9, `MODE_9, `MODE_9, 1'd0
			};
		end

		16, 18: begin
			assign PORT_A1_ADDR = A1ADDR_TOTAL << 4;
			assign PORT_B1_ADDR = B1ADDR_TOTAL << 4;
			assign PORT_A2_ADDR = C1ADDR_TOTAL << 4;
			assign PORT_B2_ADDR = D1ADDR_TOTAL << 4;
			defparam _TECHMAP_REPLACE_.MODE_BITS = { 1'b1,
				11'd10, 11'd10, 4'd0, `MODE_18, `MODE_18, `MODE_18, `MODE_18, 1'd0,
				12'd10, 12'd10, 4'd0, `MODE_18, `MODE_18, `MODE_18, `MODE_18, 1'd0
			};
		end

		default: begin
			assign PORT_A1_ADDR = A1ADDR_TOTAL;
			assign PORT_B1_ADDR = B1ADDR_TOTAL;
			assign PORT_A2_ADDR = D1ADDR_TOTAL;
			assign PORT_B2_ADDR = C1ADDR_TOTAL;
			defparam _TECHMAP_REPLACE_.MODE_BITS = { 1'b1,
				11'd10, 11'd10, 4'd0, `MODE_36, `MODE_36, `MODE_36, `MODE_36, 1'd0,
				12'd10, 12'd10, 4'd0, `MODE_36, `MODE_36, `MODE_36, `MODE_36, 1'd0
			};
		end
	endcase

	assign FLUSH1 = 1'b0;
	assign FLUSH2 = 1'b0;

	wire [17:0] PORT_A1_RDATA;
	wire [17:0] PORT_B1_RDATA;
	wire [17:0] PORT_A2_RDATA;
	wire [17:0] PORT_B2_RDATA;

	wire [17:0] PORT_A1_WDATA;
	wire [17:0] PORT_B1_WDATA;
	wire [17:0] PORT_A2_WDATA;
	wire [17:0] PORT_B2_WDATA;

	// Assign read/write data - handle special case for 9bit mode
	// parity bit for 9bit mode is placed in R/W port on bit #16
	case (CFG_DBITS)
		9: begin
			assign A1DATA = {PORT_A1_RDATA[16], PORT_A1_RDATA[7:0]};
			assign C1DATA = {PORT_A2_RDATA[16], PORT_A2_RDATA[7:0]};
			assign PORT_A1_WDATA = {18{1'b0}};
			assign PORT_B1_WDATA = {B1_WDATA_CMPL[17], B1DATA[8], B1_WDATA_CMPL[16:9], B1DATA[7:0]};
			assign PORT_A2_WDATA = {18{1'b0}};
			assign PORT_B2_WDATA = {D1_WDATA_CMPL[17], D1DATA[8], D1_WDATA_CMPL[16:9], D1DATA[7:0]};
		end
		default: begin
			assign A1DATA = PORT_A1_RDATA[CFG_DBITS-1:0];
			assign C1DATA = PORT_A2_RDATA[CFG_DBITS-1:0];
			assign PORT_A1_WDATA = {18{1'b1}};
			assign PORT_B1_WDATA = {B1_WDATA_CMPL, B1DATA};
			assign PORT_A2_WDATA = {18{1'b1}};
			assign PORT_B2_WDATA = {D1_WDATA_CMPL, D1DATA};

		end
	endcase

	wire PORT_A1_CLK = CLK1;
	wire PORT_A2_CLK = CLK2;
	wire PORT_B1_CLK = CLK1;
	wire PORT_B2_CLK = CLK2;

	wire PORT_A1_REN = A1EN;
	wire PORT_A1_WEN = 1'b0;
	wire [CFG_ENABLE_B-1:0] PORT_A1_BE = {PORT_A1_WEN,PORT_A1_WEN};

	wire PORT_A2_REN = C1EN;
	wire PORT_A2_WEN = 1'b0;
	wire [CFG_ENABLE_D-1:0] PORT_A2_BE = {PORT_A2_WEN,PORT_A2_WEN};

	wire PORT_B1_REN = 1'b0;
	wire PORT_B1_WEN = B1EN[0];
	wire [CFG_ENABLE_B-1:0] PORT_B1_BE = {B1EN[1],B1EN[0]};

	wire PORT_B2_REN = 1'b0;
	wire PORT_B2_WEN = D1EN[0];
	wire [CFG_ENABLE_D-1:0] PORT_B2_BE = {D1EN[1],D1EN[0]};

	TDP36K  _TECHMAP_REPLACE_ (
		.WDATA_A1_i(PORT_A1_WDATA),
		.RDATA_A1_o(PORT_A1_RDATA),
		.ADDR_A1_i(PORT_A1_ADDR),
		.CLK_A1_i(PORT_A1_CLK),
		.REN_A1_i(PORT_A1_REN),
		.WEN_A1_i(PORT_A1_WEN),
		.BE_A1_i(PORT_A1_BE),

		.WDATA_A2_i(PORT_A2_WDATA),
		.RDATA_A2_o(PORT_A2_RDATA),
		.ADDR_A2_i(PORT_A2_ADDR),
		.CLK_A2_i(PORT_A2_CLK),
		.REN_A2_i(PORT_A2_REN),
		.WEN_A2_i(PORT_A2_WEN),
		.BE_A2_i(PORT_A2_BE),

		.WDATA_B1_i(PORT_B1_WDATA),
		.RDATA_B1_o(PORT_B1_RDATA),
		.ADDR_B1_i(PORT_B1_ADDR),
		.CLK_B1_i(PORT_B1_CLK),
		.REN_B1_i(PORT_B1_REN),
		.WEN_B1_i(PORT_B1_WEN),
		.BE_B1_i(PORT_B1_BE),

		.WDATA_B2_i(PORT_B2_WDATA),
		.RDATA_B2_o(PORT_B2_RDATA),
		.ADDR_B2_i(PORT_B2_ADDR),
		.CLK_B2_i(PORT_B2_CLK),
		.REN_B2_i(PORT_B2_REN),
		.WEN_B2_i(PORT_B2_WEN),
		.BE_B2_i(PORT_B2_BE),

		.FLUSH1_i(FLUSH1),
		.FLUSH2_i(FLUSH2)
	);
endmodule
