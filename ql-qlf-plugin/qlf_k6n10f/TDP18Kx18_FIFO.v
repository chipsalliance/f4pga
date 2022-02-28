// Copyright (C) 2022  The SymbiFlow Authors.
//
// Use of this source code is governed by a ISC-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/ISC
//
// SPDX-License-Identifier:ISC

module TDP18K_FIFO (
	RMODE_A,
	RMODE_B,
	WMODE_A,
	WMODE_B,
	WEN_A,
	WEN_B,
	REN_A,
	REN_B,
	CLK_A,
	CLK_B,
	BE_A,
	BE_B,
	ADDR_A,
	ADDR_B,
	WDATA_A,
	WDATA_B,
	RDATA_A,
	RDATA_B,
	EMPTY,
	EPO,
	EWM,
	UNDERRUN,
	FULL,
	FMO,
	FWM,
	OVERRUN,
	FLUSH,
	FMODE,
	SYNC_FIFO,
	POWERDN,
	SLEEP,
	PROTECT,
	UPAF,
	UPAE,
	PL_INIT,
	PL_ENA,
	PL_WEN,
	PL_REN,
	PL_CLK,
	PL_ADDR,
	PL_DATA_IN,
	PL_DATA_OUT,
	RAM_ID
);
	input wire [2:0] RMODE_A;
	input wire [2:0] RMODE_B;
	input wire [2:0] WMODE_A;
	input wire [2:0] WMODE_B;
	input wire WEN_A;
	input wire WEN_B;
	input wire REN_A;
	input wire REN_B;
	(* clkbuf_sink *)
	input wire CLK_A;
	(* clkbuf_sink *)
	input wire CLK_B;
	input wire [1:0] BE_A;
	input wire [1:0] BE_B;
	input wire [13:0] ADDR_A;
	input wire [13:0] ADDR_B;
	input wire [17:0] WDATA_A;
	input wire [17:0] WDATA_B;
	output reg [17:0] RDATA_A;
	output reg [17:0] RDATA_B;
	output wire EMPTY;
	output wire EPO;
	output wire EWM;
	output wire UNDERRUN;
	output wire FULL;
	output wire FMO;
	output wire FWM;
	output wire OVERRUN;
	input wire FLUSH;
	input wire FMODE;
	input wire SYNC_FIFO;
	input wire POWERDN;
	input wire SLEEP;
	input wire PROTECT;
	input wire [10:0] UPAF;
	input wire [10:0] UPAE;
	input PL_INIT;
	input PL_ENA;
	input PL_WEN;
	input PL_REN;
	input PL_CLK;
	input [31:0] PL_ADDR;
	input [17:0] PL_DATA_IN;
	output reg [17:0] PL_DATA_OUT;
	input [15:0] RAM_ID;
	reg [17:0] wmsk_a;
	reg [17:0] wmsk_b;
	wire [8:0] addr_a;
	wire [8:0] addr_b;
	reg [4:0] addr_a_d;
	reg [4:0] addr_b_d;
	wire [17:0] ram_rdata_a;
	wire [17:0] ram_rdata_b;
	reg [17:0] aligned_wdata_a;
	reg [17:0] aligned_wdata_b;
	wire ren_o;
	wire [10:0] ff_raddr;
	wire [10:0] ff_waddr;
	wire [13:0] ram_addr_a;
	wire [13:0] ram_addr_b;
	wire [3:0] ram_waddr_a;
	wire [3:0] ram_waddr_b;
	wire preload;
	wire my_id;
	wire initn;
	wire smux_rclk;
	wire smux_wclk;
	wire real_fmode;
	wire [3:0] raw_fflags;
	reg [1:0] fifo_rmode;
	reg [1:0] fifo_wmode;
	wire smux_clk_a;
	wire smux_clk_b;
	wire ram_ren_a;
	wire ram_ren_b;
	wire ram_wen_a;
	wire ram_wen_b;
	wire cen_a;
	wire cen_b;
	localparam MODE_9 = 3'b101;
	always @(*) begin
		fifo_rmode = (RMODE_B == MODE_9 ? 2'b10 : 2'b01);
		fifo_wmode = (WMODE_A == MODE_9 ? 2'b10 : 2'b01);
	end
	assign my_id = (PL_ADDR[31:16] == RAM_ID) | PL_INIT;
	assign preload = (PROTECT ? 1'b0 : my_id & PL_ENA);
	assign smux_clk_a = (preload ? PL_CLK : CLK_A);
	assign smux_clk_b = (preload ? 0 : (FMODE ? (SYNC_FIFO ? CLK_A : CLK_B) : CLK_B));
	assign real_fmode = (preload ? 1'b0 : FMODE);
	assign ram_ren_b = (preload ? PL_REN : (real_fmode ? ren_o : REN_B));
	assign ram_wen_a = (preload ? PL_WEN : (FMODE ? ~FULL & WEN_A : WEN_A));
	assign ram_ren_a = (preload ? 1'b1 : (FMODE ? 0 : REN_A));
	assign ram_wen_b = (preload ? 1'b1 : (FMODE ? 1'b0 : WEN_B));
	assign cen_b = ram_ren_b | ram_wen_b;
	assign cen_a = ram_ren_a | ram_wen_a;
	assign ram_waddr_b = (preload ? 4'b0000 : (real_fmode ? {ff_raddr[0], 3'b000} : ADDR_B[3:0]));
	assign ram_waddr_a = (preload ? 4'b0000 : (real_fmode ? {ff_waddr[0], 3'b000} : ADDR_A[3:0]));
	assign ram_addr_b = (preload ? {PL_ADDR[10:0], 3'h0} : (real_fmode ? {ff_raddr[10:0], 3'h0} : {ADDR_B[13:4], addr_b_d[3:0]}));
	assign ram_addr_a = (preload ? {PL_ADDR[10:0], 3'h0} : (real_fmode ? {ff_waddr[10:0], 3'b000} : {ADDR_A[13:4], addr_a_d[3:0]}));
	always @(posedge CLK_A) addr_a_d[3:0] <= ADDR_A[3:0];
	always @(posedge CLK_B) addr_b_d[3:0] <= ADDR_B[3:0];
	sram1024x18 uram(
		.clk_a(smux_clk_a),
		.cen_a(~cen_a),
		.wen_a(~ram_wen_a),
		.addr_a(ram_addr_a[13:4]),
		.wmsk_a(wmsk_a),
		.wdata_a(aligned_wdata_a),
		.rdata_a(ram_rdata_a),
		.clk_b(smux_clk_b),
		.cen_b(~cen_b),
		.wen_b(~ram_wen_b),
		.addr_b(ram_addr_b[13:4]),
		.wmsk_b(wmsk_b),
		.wdata_b(aligned_wdata_b),
		.rdata_b(ram_rdata_b)
	);
	fifo_ctl #(
		.ADDR_WIDTH(11),
		.FIFO_WIDTH(2)
	) fifo_ctl(
		.rclk(smux_clk_b),
		.rst_R_n(~FLUSH),
		.wclk(smux_clk_a),
		.rst_W_n(~FLUSH),
		.ren(REN_B),
		.wen(ram_wen_a),
		.depth(3'b000),
		.sync(SYNC_FIFO),
		.rmode(fifo_rmode),
		.wmode(fifo_wmode),
		.ren_o(ren_o),
		.fflags({FULL, FMO, FWM, OVERRUN, EMPTY, EPO, EWM, UNDERRUN}),
		.raddr(ff_raddr),
		.waddr(ff_waddr),
		.upaf(UPAF),
		.upae(UPAE)
	);
	always @(*) begin : PRELOAD_DATA
		if (preload & ram_ren_a)
			PL_DATA_OUT = ram_rdata_a;
		else
			PL_DATA_OUT = PL_DATA_IN;
	end
	localparam MODE_1 = 3'b001;
	localparam MODE_18 = 3'b110;
	localparam MODE_2 = 3'b010;
	localparam MODE_4 = 3'b100;
	always @(*) begin : WDATA_MODE_SEL
		if (ram_wen_a == 1) begin
			if (preload) begin
				aligned_wdata_a = PL_DATA_IN;
				wmsk_a = 18'h00000;
			end
			else
				case (WMODE_A)
					MODE_18: begin
						aligned_wdata_a = WDATA_A;
						{wmsk_a[17], wmsk_a[15:8]} = (FMODE ? 9'h000 : (BE_A[1] ? 9'h000 : 9'h1ff));
						{wmsk_a[16], wmsk_a[7:0]} = (FMODE ? 9'h000 : (BE_A[0] ? 9'h000 : 9'h1ff));
					end
					MODE_9: begin
						aligned_wdata_a = {{2 {WDATA_A[8]}}, {2 {WDATA_A[7:0]}}};
						{wmsk_a[17], wmsk_a[15:8]} = (ram_waddr_a[3] ? 9'h000 : 9'h1ff);
						{wmsk_a[16], wmsk_a[7:0]} = (ram_waddr_a[3] ? 9'h1ff : 9'h000);
					end
					MODE_4: begin
						aligned_wdata_a = {2'b00, {4 {WDATA_A[3:0]}}};
						wmsk_a[17:16] = 2'b11;
						wmsk_a[15:12] = (ram_waddr_a[3:2] == 2'b11 ? 4'h0 : 4'hf);
						wmsk_a[11:8] = (ram_waddr_a[3:2] == 2'b10 ? 4'h0 : 4'hf);
						wmsk_a[7:4] = (ram_waddr_a[3:2] == 2'b01 ? 4'h0 : 4'hf);
						wmsk_a[3:0] = (ram_waddr_a[3:2] == 2'b00 ? 4'h0 : 4'hf);
					end
					MODE_2: begin
						aligned_wdata_a = {2'b00, {8 {WDATA_A[1:0]}}};
						wmsk_a[17:16] = 2'b11;
						wmsk_a[15:14] = (ram_waddr_a[3:1] == 3'b111 ? 2'h0 : 2'h3);
						wmsk_a[13:12] = (ram_waddr_a[3:1] == 3'b110 ? 2'h0 : 2'h3);
						wmsk_a[11:10] = (ram_waddr_a[3:1] == 3'b101 ? 2'h0 : 2'h3);
						wmsk_a[9:8] = (ram_waddr_a[3:1] == 3'b100 ? 2'h0 : 2'h3);
						wmsk_a[7:6] = (ram_waddr_a[3:1] == 3'b011 ? 2'h0 : 2'h3);
						wmsk_a[5:4] = (ram_waddr_a[3:1] == 3'b010 ? 2'h0 : 2'h3);
						wmsk_a[3:2] = (ram_waddr_a[3:1] == 3'b001 ? 2'h0 : 2'h3);
						wmsk_a[1:0] = (ram_waddr_a[3:1] == 3'b000 ? 2'h0 : 2'h3);
					end
					MODE_1: begin
						aligned_wdata_a = {2'b00, {16 {WDATA_A[0]}}};
						wmsk_a = 18'h3ffff;
						wmsk_a[{1'b0, ram_waddr_a[3:0]}] = 0;
					end
					default: wmsk_a = 18'h3ffff;
				endcase
		end
		else begin
			aligned_wdata_a = 18'h00000;
			wmsk_a = 18'h3ffff;
		end
		if (ram_wen_b == 1)
			case (WMODE_B)
				MODE_18: begin
					aligned_wdata_b = WDATA_B;
					{wmsk_b[17], wmsk_b[15:8]} = (BE_B[1] ? 9'h000 : 9'h1ff);
					{wmsk_b[16], wmsk_b[7:0]} = (BE_B[0] ? 9'h000 : 9'h1ff);
				end
				MODE_9: begin
					aligned_wdata_b = {{2 {WDATA_B[8]}}, {2 {WDATA_B[7:0]}}};
					{wmsk_b[17], wmsk_b[15:8]} = (ram_waddr_b[3] ? 9'h000 : 9'h1ff);
					{wmsk_b[16], wmsk_b[7:0]} = (ram_waddr_b[3] ? 9'h1ff : 9'h000);
				end
				MODE_4: begin
					aligned_wdata_b = {2'b00, {4 {WDATA_B[3:0]}}};
					wmsk_b[17:16] = 2'b11;
					wmsk_b[15:12] = (ram_waddr_b[3:2] == 2'b11 ? 4'h0 : 4'hf);
					wmsk_b[11:8] = (ram_waddr_b[3:2] == 2'b10 ? 4'h0 : 4'hf);
					wmsk_b[7:4] = (ram_waddr_b[3:2] == 2'b01 ? 4'h0 : 4'hf);
					wmsk_b[3:0] = (ram_waddr_b[3:2] == 2'b00 ? 4'h0 : 4'hf);
				end
				MODE_2: begin
					aligned_wdata_b = {2'b00, {8 {WDATA_B[1:0]}}};
					wmsk_b[17:16] = 2'b11;
					wmsk_b[15:14] = (ram_waddr_b[3:1] == 3'b111 ? 2'h0 : 2'h3);
					wmsk_b[13:12] = (ram_waddr_b[3:1] == 3'b110 ? 2'h0 : 2'h3);
					wmsk_b[11:10] = (ram_waddr_b[3:1] == 3'b101 ? 2'h0 : 2'h3);
					wmsk_b[9:8] = (ram_waddr_b[3:1] == 3'b100 ? 2'h0 : 2'h3);
					wmsk_b[7:6] = (ram_waddr_b[3:1] == 3'b011 ? 2'h0 : 2'h3);
					wmsk_b[5:4] = (ram_waddr_b[3:1] == 3'b010 ? 2'h0 : 2'h3);
					wmsk_b[3:2] = (ram_waddr_b[3:1] == 3'b001 ? 2'h0 : 2'h3);
					wmsk_b[1:0] = (ram_waddr_b[3:1] == 3'b000 ? 2'h0 : 2'h3);
				end
				MODE_1: begin
					aligned_wdata_b = {2'b00, {16 {WDATA_B[0]}}};
					wmsk_b = 18'h3ffff;
					wmsk_b[{1'b0, ram_waddr_b[3:0]}] = 0;
				end
				default: wmsk_b = 18'h3ffff;
			endcase
		else begin
			aligned_wdata_b = 18'b000000000000000000;
			wmsk_b = 18'h3ffff;
		end
	end
	always @(*) begin : RDATA_A_MODE_SEL
		case (RMODE_A)
			default: RDATA_A = 18'h00000;
			MODE_18: RDATA_A = ram_rdata_a;
			MODE_9: begin
				RDATA_A[17:9] = 9'h000;
				RDATA_A[8:0] = (ram_addr_a[3] ? {ram_rdata_a[17], ram_rdata_a[15:8]} : {ram_rdata_a[16], ram_rdata_a[7:0]});
			end
			MODE_4: begin
				RDATA_A[17:4] = 14'h0000;
				case (ram_addr_a[3:2])
					3: RDATA_A[3:0] = ram_rdata_a[15:12];
					2: RDATA_A[3:0] = ram_rdata_a[11:8];
					1: RDATA_A[3:0] = ram_rdata_a[7:4];
					0: RDATA_A[3:0] = ram_rdata_a[3:0];
				endcase
			end
			MODE_2: begin
				RDATA_A[17:2] = 16'h0000;
				case (ram_addr_a[3:1])
					7: RDATA_A[1:0] = ram_rdata_a[15:14];
					6: RDATA_A[1:0] = ram_rdata_a[13:12];
					5: RDATA_A[1:0] = ram_rdata_a[11:10];
					4: RDATA_A[1:0] = ram_rdata_a[9:8];
					3: RDATA_A[1:0] = ram_rdata_a[7:6];
					2: RDATA_A[1:0] = ram_rdata_a[5:4];
					1: RDATA_A[1:0] = ram_rdata_a[3:2];
					0: RDATA_A[1:0] = ram_rdata_a[1:0];
				endcase
			end
			MODE_1: begin
				RDATA_A[17:1] = 17'h00000;
				RDATA_A[0] = ram_rdata_a[ram_addr_a[3:0]];
			end
		endcase
	end
	always @(*)
		case (RMODE_B)
			default: RDATA_B = 18'h15566;
			MODE_18: RDATA_B = ram_rdata_b;
			MODE_9: begin
				RDATA_B[17:9] = 1'sb1;
				RDATA_B[8:0] = (ram_addr_b[3] ? {ram_rdata_b[17], ram_rdata_b[15:8]} : {ram_rdata_b[16], ram_rdata_b[7:0]});
			end
			MODE_4:
				case (ram_addr_b[3:2])
					3: RDATA_B[3:0] = ram_rdata_b[15:12];
					2: RDATA_B[3:0] = ram_rdata_b[11:8];
					1: RDATA_B[3:0] = ram_rdata_b[7:4];
					0: RDATA_B[3:0] = ram_rdata_b[3:0];
				endcase
			MODE_2:
				case (ram_addr_b[3:1])
					7: RDATA_B[1:0] = ram_rdata_b[15:14];
					6: RDATA_B[1:0] = ram_rdata_b[13:12];
					5: RDATA_B[1:0] = ram_rdata_b[11:10];
					4: RDATA_B[1:0] = ram_rdata_b[9:8];
					3: RDATA_B[1:0] = ram_rdata_b[7:6];
					2: RDATA_B[1:0] = ram_rdata_b[5:4];
					1: RDATA_B[1:0] = ram_rdata_b[3:2];
					0: RDATA_B[1:0] = ram_rdata_b[1:0];
				endcase
			MODE_1: RDATA_B[0] = ram_rdata_b[ram_addr_b[3:0]];
		endcase
endmodule
