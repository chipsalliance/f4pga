// Copyright (C) 2022  The SymbiFlow Authors.
//
// Use of this source code is governed by a ISC-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/ISC
//
// SPDX-License-Identifier:ISC

module fifo_ctl (
	raddr,
	waddr,
	fflags,
	ren_o,
	sync,
	depth,
	rmode,
	wmode,
	rclk,
	rst_R_n,
	wclk,
	rst_W_n,
	ren,
	wen,
	upaf,
	upae
);
	parameter ADDR_WIDTH = 11;
	parameter FIFO_WIDTH = 3'd2;
	localparam ADDR_PLUS_ONE = ADDR_WIDTH + 1;
	output wire [ADDR_WIDTH - 1:0] raddr;
	output wire [ADDR_WIDTH - 1:0] waddr;
	output wire [7:0] fflags;
	output wire ren_o;
	input wire sync;
	input wire [2:0] depth;
	input wire [1:0] rmode;
	input wire [1:0] wmode;
	(* clkbuf_sink *)
	input wire rclk;
	input wire rst_R_n;
	(* clkbuf_sink *)
	input wire wclk;
	input wire rst_W_n;
	input wire ren;
	input wire wen;
	input wire [ADDR_WIDTH - 1:0] upaf;
	input wire [ADDR_WIDTH - 1:0] upae;
	reg [ADDR_WIDTH:0] pushtopop1;
	reg [ADDR_WIDTH:0] pushtopop2;
	reg [ADDR_WIDTH:0] poptopush1;
	reg [ADDR_WIDTH:0] poptopush2;
	wire [ADDR_WIDTH:0] pushtopop0;
	wire [ADDR_WIDTH:0] poptopush0;
	wire [ADDR_WIDTH:0] smux_poptopush;
	wire [ADDR_WIDTH:0] smux_pushtopop;
	assign smux_poptopush = (sync ? poptopush0 : poptopush2);
	assign smux_pushtopop = (sync ? pushtopop0 : pushtopop2);
	always @(posedge rclk or negedge rst_R_n)
		if (~rst_R_n) begin
			pushtopop1 <= #(1) {ADDR_WIDTH + 1{1'h0}};
			pushtopop2 <= #(1) {ADDR_WIDTH + 1{1'h0}};
		end
		else begin
			pushtopop1 <= #(1) pushtopop0;
			pushtopop2 <= #(1) pushtopop1;
		end
	always @(posedge wclk or negedge rst_W_n)
		if (~rst_W_n) begin
			poptopush1 <= #(1) {ADDR_WIDTH + 1{1'h0}};
			poptopush2 <= #(1) {ADDR_WIDTH + 1{1'h0}};
		end
		else begin
			poptopush1 <= #(1) poptopush0;
			poptopush2 <= #(1) poptopush1;
		end
	fifo_push #(.ADDR_WIDTH(ADDR_WIDTH)) u_fifo_push(
		.wclk(wclk),
		.wen(wen),
		.rst_n(rst_W_n),
		.rmode(rmode),
		.wmode(wmode),
		.gcout(pushtopop0),
		.gcin(smux_poptopush),
		.ff_waddr(waddr),
		.depth(depth),
		.pushflags(fflags[7:4]),
		.upaf(upaf)
	);
	fifo_pop #(
		.ADDR_WIDTH(ADDR_WIDTH),
		.FIFO_WIDTH(FIFO_WIDTH)
	) u_fifo_pop(
		.rclk(rclk),
		.ren_in(ren),
		.rst_n(rst_R_n),
		.rmode(rmode),
		.wmode(wmode),
		.ren_o(ren_o),
		.gcout(poptopush0),
		.gcin(smux_pushtopop),
		.out_raddr(raddr),
		.depth(depth),
		.popflags(fflags[3:0]),
		.upae(upae)
	);
endmodule
module fifo_push (
	pushflags,
	gcout,
	ff_waddr,
	rst_n,
	wclk,
	wen,
	rmode,
	wmode,
	depth,
	gcin,
	upaf
);
	parameter ADDR_WIDTH = 11;
	output wire [3:0] pushflags;
	output wire [ADDR_WIDTH:0] gcout;
	output wire [ADDR_WIDTH - 1:0] ff_waddr;
	input rst_n;
	input wclk;
	input wen;
	input [1:0] rmode;
	input [1:0] wmode;
	input [2:0] depth;
	input [ADDR_WIDTH:0] gcin;
	input [ADDR_WIDTH - 1:0] upaf;
	reg full_next;
	reg full;
	reg paf_next;
	reg paf;
	reg fmo;
	reg fmo_next;
	reg overflow;
	reg p1;
	reg p2;
	reg f1;
	reg f2;
	reg q1;
	reg q2;
	reg [1:0] gmode;
	reg [ADDR_WIDTH:0] waddr;
	reg [ADDR_WIDTH:0] raddr;
	reg [ADDR_WIDTH:0] gcout_reg;
	reg [ADDR_WIDTH:0] gcout_next;
	reg [ADDR_WIDTH:0] raddr_next;
	reg [ADDR_WIDTH - 1:0] paf_thresh;
	wire overflow_next;
	wire [ADDR_WIDTH:0] waddr_next;
	wire [ADDR_WIDTH:0] gc8out_next;
	wire [ADDR_WIDTH - 1:0] gc16out_next;
	wire [ADDR_WIDTH - 2:0] gc32out_next;
	wire [ADDR_WIDTH:0] tmp;
	wire [ADDR_WIDTH:0] next_count;
	wire [ADDR_WIDTH:0] count;
	reg [ADDR_WIDTH:0] fbytes;
	genvar i;
	assign next_count = fbytes - (waddr_next >= raddr_next ? waddr_next - raddr_next : (~raddr_next + waddr_next) + 1);
	assign count = fbytes - (waddr >= raddr ? waddr - raddr : (~raddr + waddr) + 1);
	always @(*) begin
		case (depth)
			3'b000: fbytes = {ADDR_WIDTH + 1{1'h0}} | 12'd2048;
			3'b001: fbytes = {ADDR_WIDTH + 1{1'h0}} | 11'd1024;
			3'b010: fbytes = {ADDR_WIDTH + 1{1'h0}} | 10'd512;
			3'b011: fbytes = {ADDR_WIDTH + 1{1'h0}} | 9'd256;
			3'b100: fbytes = {ADDR_WIDTH + 1{1'h0}} | 8'd128;
			3'b101: fbytes = {ADDR_WIDTH + 1{1'h0}} | 7'd64;
			3'b110: fbytes = {ADDR_WIDTH + 1{1'h0}} | 6'd32;
			3'b111: fbytes = {ADDR_WIDTH + 1{1'h0}} | 13'd4096;
		endcase
		paf_thresh = (wmode ? (wmode[0] ? upaf << 1 : upaf) : upaf << 2);
	end
	always @(*)
		case (wmode)
			2'h0, 2'h1, 2'h2: begin
				full_next = (wen ? f1 : f2);
				fmo_next = (wen ? p1 : p2);
				paf_next = (wen ? q1 : q2);
			end
			default: begin
				full_next = 1'b0;
				fmo_next = 1'b0;
				paf_next = 1'b0;
			end
		endcase
	always @(*) begin : PUSH_FULL_FLAGS
		f1 = 1'b0;
		f2 = 1'b0;
		p1 = 1'b0;
		p2 = 1'b0;
		q1 = next_count < paf_thresh;
		q2 = count < paf_thresh;
		case (wmode)
			2'h0:
				case (depth)
					3'h0: begin
						f1 = {~waddr_next[11], waddr_next[10:2]} == raddr_next[11:2];
						f2 = {~waddr[11], waddr[10:2]} == raddr_next[11:2];
						p1 = ((waddr_next[10:2] + 1) & 9'h1ff) == raddr_next[10:2];
						p2 = ((waddr[10:2] + 1) & 9'h1ff) == raddr_next[10:2];
					end
					3'h1: begin
						f1 = {~waddr_next[10], waddr_next[9:2]} == raddr_next[10:2];
						f2 = {~waddr[10], waddr[9:2]} == raddr_next[10:2];
						p1 = ((waddr_next[9:2] + 1) & 8'hff) == raddr_next[9:2];
						p2 = ((waddr[9:2] + 1) & 8'hff) == raddr_next[9:2];
					end
					3'h2: begin
						f1 = {~waddr_next[9], waddr_next[8:2]} == raddr_next[9:2];
						f2 = {~waddr[9], waddr[8:2]} == raddr_next[9:2];
						p1 = ((waddr_next[8:2] + 1) & 7'h7f) == raddr_next[8:2];
						p2 = ((waddr[8:2] + 1) & 7'h7f) == raddr_next[8:2];
					end
					3'h3: begin
						f1 = {~waddr_next[8], waddr_next[7:2]} == raddr_next[8:2];
						f2 = {~waddr[8], waddr[7:2]} == raddr_next[8:2];
						p1 = ((waddr_next[7:2] + 1) & 6'h3f) == raddr_next[7:2];
						p2 = ((waddr[7:2] + 1) & 6'h3f) == raddr_next[7:2];
					end
					3'h4: begin
						f1 = {~waddr_next[7], waddr_next[6:2]} == raddr_next[7:2];
						f2 = {~waddr[7], waddr[6:2]} == raddr_next[7:2];
						p1 = ((waddr_next[6:2] + 1) & 5'h1f) == raddr_next[6:2];
						p2 = ((waddr[6:2] + 1) & 5'h1f) == raddr_next[6:2];
					end
					3'h5: begin
						f1 = {~waddr_next[6], waddr_next[5:2]} == raddr_next[6:2];
						f2 = {~waddr[6], waddr[5:2]} == raddr_next[6:2];
						p1 = ((waddr_next[5:2] + 1) & 4'hf) == raddr_next[5:2];
						p2 = ((waddr[5:2] + 1) & 4'hf) == raddr_next[5:2];
					end
					3'h6: begin
						f1 = {~waddr_next[5], waddr_next[4:2]} == raddr_next[5:2];
						f2 = {~waddr[5], waddr[4:2]} == raddr_next[5:2];
						p1 = ((waddr_next[4:2] + 1) & 3'h7) == raddr_next[4:2];
						p2 = ((waddr[4:2] + 1) & 3'h7) == raddr_next[4:2];
					end
					3'h7: begin
						f1 = {~waddr_next[ADDR_WIDTH], waddr_next[ADDR_WIDTH - 1:2]} == raddr_next[ADDR_WIDTH:2];
						f2 = {~waddr[ADDR_WIDTH], waddr[10:2]} == raddr_next[ADDR_WIDTH:2];
						p1 = ((waddr_next[ADDR_WIDTH - 1:2] + 1) & {ADDR_WIDTH - 2 {1'b1}}) == raddr_next[ADDR_WIDTH - 1:2];
						p2 = ((waddr[ADDR_WIDTH - 1:2] + 1) & {ADDR_WIDTH - 2 {1'b1}}) == raddr_next[ADDR_WIDTH - 1:2];
					end
				endcase
			2'h1:
				case (depth)
					3'h0: begin
						f1 = {~waddr_next[11], waddr_next[10:1]} == raddr_next[11:1];
						f2 = {~waddr[11], waddr[10:1]} == raddr_next[11:1];
						p1 = ((waddr_next[10:1] + 1) & 10'h3ff) == raddr_next[10:1];
						p2 = ((waddr[10:1] + 1) & 10'h3ff) == raddr_next[10:1];
					end
					3'h1: begin
						f1 = {~waddr_next[10], waddr_next[9:1]} == raddr_next[10:1];
						f2 = {~waddr[10], waddr[9:1]} == raddr_next[10:1];
						p1 = ((waddr_next[9:1] + 1) & 9'h1ff) == raddr_next[9:1];
						p2 = ((waddr[9:1] + 1) & 9'h1ff) == raddr_next[9:1];
					end
					3'h2: begin
						f1 = {~waddr_next[9], waddr_next[8:1]} == raddr_next[9:1];
						f2 = {~waddr[9], waddr[8:1]} == raddr_next[9:1];
						p1 = ((waddr_next[8:1] + 1) & 8'hff) == raddr_next[8:1];
						p2 = ((waddr[8:1] + 1) & 8'hff) == raddr_next[8:1];
					end
					3'h3: begin
						f1 = {~waddr_next[8], waddr_next[7:1]} == raddr_next[8:1];
						f2 = {~waddr[8], waddr[7:1]} == raddr_next[8:1];
						p1 = ((waddr_next[7:1] + 1) & 7'h7f) == raddr_next[7:1];
						p2 = ((waddr[7:1] + 1) & 7'h7f) == raddr_next[7:1];
					end
					3'h4: begin
						f1 = {~waddr_next[7], waddr_next[6:1]} == raddr_next[7:1];
						f2 = {~waddr[7], waddr[6:1]} == raddr_next[7:1];
						p1 = ((waddr_next[6:1] + 1) & 6'h3f) == raddr_next[6:1];
						p2 = ((waddr[6:1] + 1) & 6'h3f) == raddr_next[6:1];
					end
					3'h5: begin
						f1 = {~waddr_next[6], waddr_next[5:1]} == raddr_next[6:1];
						f2 = {~waddr[6], waddr[5:1]} == raddr_next[6:1];
						p1 = ((waddr_next[5:1] + 1) & 5'h1f) == raddr_next[5:1];
						p2 = ((waddr[5:1] + 1) & 5'h1f) == raddr_next[5:1];
					end
					3'h6: begin
						f1 = {~waddr_next[5], waddr_next[4:1]} == raddr_next[5:1];
						f2 = {~waddr[5], waddr[4:1]} == raddr_next[5:1];
						p1 = ((waddr_next[4:1] + 1) & 4'hf) == raddr_next[4:1];
						p2 = ((waddr[4:1] + 1) & 4'hf) == raddr_next[4:1];
					end
					3'h7: begin
						f1 = {~waddr_next[ADDR_WIDTH], waddr_next[ADDR_WIDTH - 1:1]} == raddr_next[ADDR_WIDTH:1];
						f2 = {~waddr[11], waddr[ADDR_WIDTH - 1:1]} == raddr_next[ADDR_WIDTH:1];
						p1 = ((waddr_next[ADDR_WIDTH - 1:1] + 1) & {ADDR_WIDTH - 1 {1'b1}}) == raddr_next[ADDR_WIDTH - 1:1];
						p2 = ((waddr[ADDR_WIDTH - 1:1] + 1) & {ADDR_WIDTH - 1 {1'b1}}) == raddr_next[ADDR_WIDTH - 1:1];
					end
				endcase
			2'h2:
				case (depth)
					3'h0: begin
						f1 = {~waddr_next[11], waddr_next[10:0]} == raddr_next[11:0];
						f2 = {~waddr[11], waddr[10:0]} == raddr_next[11:0];
						p1 = ((waddr_next[10:0] + 1) & 11'h7ff) == raddr_next[10:0];
						p2 = ((waddr[10:0] + 1) & 11'h7ff) == raddr_next[10:0];
					end
					3'h1: begin
						f1 = {~waddr_next[10], waddr_next[9:0]} == raddr_next[10:0];
						f2 = {~waddr[10], waddr[9:0]} == raddr_next[10:0];
						p1 = ((waddr_next[9:0] + 1) & 10'h3ff) == raddr_next[9:0];
						p2 = ((waddr[9:0] + 1) & 10'h3ff) == raddr_next[9:0];
					end
					3'h2: begin
						f1 = {~waddr_next[9], waddr_next[8:0]} == raddr_next[9:0];
						f2 = {~waddr[9], waddr[8:0]} == raddr_next[9:0];
						p1 = ((waddr_next[8:0] + 1) & 9'h1ff) == raddr_next[8:0];
						p2 = ((waddr[8:0] + 1) & 9'h1ff) == raddr_next[8:0];
					end
					3'h3: begin
						f1 = {~waddr_next[8], waddr_next[7:0]} == raddr_next[8:0];
						f2 = {~waddr[8], waddr[7:0]} == raddr_next[8:0];
						p1 = ((waddr_next[7:0] + 1) & 8'hff) == raddr_next[7:0];
						p2 = ((waddr[7:0] + 1) & 8'hff) == raddr_next[7:0];
					end
					3'h4: begin
						f1 = {~waddr_next[7], waddr_next[6:0]} == raddr_next[7:0];
						f2 = {~waddr[7], waddr[6:0]} == raddr_next[7:0];
						p1 = ((waddr_next[6:0] + 1) & 7'h7f) == raddr_next[6:0];
						p2 = ((waddr[6:0] + 1) & 7'h7f) == raddr_next[6:0];
					end
					3'h5: begin
						f1 = {~waddr_next[6], waddr_next[5:0]} == raddr_next[6:0];
						f2 = {~waddr[6], waddr[5:0]} == raddr_next[6:0];
						p1 = ((waddr_next[5:0] + 1) & 6'h3f) == raddr_next[5:0];
						p2 = ((waddr[5:0] + 1) & 6'h3f) == raddr_next[5:0];
					end
					3'h6: begin
						f1 = {~waddr_next[5], waddr_next[4:0]} == raddr_next[5:0];
						f2 = {~waddr[5], waddr[4:0]} == raddr_next[5:0];
						p1 = ((waddr_next[4:0] + 1) & 5'h1f) == raddr_next[4:0];
						p2 = ((waddr[4:0] + 1) & 5'h1f) == raddr_next[4:0];
					end
					3'h7: begin
						f1 = {~waddr_next[ADDR_WIDTH], waddr_next[ADDR_WIDTH - 1:0]} == raddr_next[ADDR_WIDTH:0];
						f2 = {~waddr[ADDR_WIDTH], waddr[ADDR_WIDTH - 1:0]} == raddr_next[ADDR_WIDTH:0];
						p1 = ((waddr_next[ADDR_WIDTH - 1:0] + 1) & {ADDR_WIDTH {1'b1}}) == raddr_next[ADDR_WIDTH - 1:0];
						p2 = ((waddr[ADDR_WIDTH - 1:0] + 1) & {ADDR_WIDTH {1'b1}}) == raddr_next[ADDR_WIDTH - 1:0];
					end
				endcase
			2'h3: begin
				f1 = 1'b0;
				f2 = 1'b0;
				p1 = 1'b0;
				p2 = 1'b0;
			end
		endcase
	end
	always @(*)
		case (wmode)
			2'h0: gmode = 2'h0;
			2'h1: gmode = (rmode == 2'h0 ? 2'h0 : 2'h1);
			2'h2: gmode = (rmode == 2'h2 ? 2'h2 : rmode);
			2'h3: gmode = 2'h3;
		endcase
	assign gc8out_next = (waddr_next >> 1) ^ waddr_next;
	assign gc16out_next = (waddr_next >> 2) ^ (waddr_next >> 1);
	assign gc32out_next = (waddr_next >> 3) ^ (waddr_next >> 2);
	always @(*)
		if (wen)
			case (gmode)
				2'h2: gcout_next = gc8out_next;
				2'h1: gcout_next = {1'b0, gc16out_next};
				2'h0: gcout_next = {2'b00, gc32out_next};
				default: gcout_next = 12'h000;
			endcase
		else
			gcout_next = 12'h000;
	always @(posedge wclk or negedge rst_n)
		if (~rst_n) begin
			full <= #(1) 1'b0;
			fmo <= #(1) 1'b0;
			paf <= #(1) 1'b0;
			raddr <= #(1) ADDR_WIDTH + 1'h0;
		end
		else begin
			full <= #(1) full_next;
			fmo <= #(1) fmo_next;
			paf <= #(1) paf_next;
			case (gmode)
				0: raddr <= #(1) raddr_next & {{ADDR_WIDTH - 1 {1'b1}}, 2'b00};
				1: raddr <= #(1) raddr_next & {{ADDR_WIDTH {1'b1}}, 1'b0};
				2: raddr <= #(1) raddr_next & {ADDR_WIDTH + 1 {1'b1}};
				3: raddr <= #(1) 12'h000;
			endcase
		end
	assign overflow_next = full & wen;
	always @(posedge wclk or negedge rst_n)
		if (~rst_n)
			overflow <= #(1) 1'b0;
		else if (wen == 1'b1)
			overflow <= #(1) overflow_next;
	always @(posedge wclk or negedge rst_n)
		if (~rst_n) begin
			waddr <= #(1) {ADDR_WIDTH + 1 {1'b0}};
			gcout_reg <= #(1) {ADDR_WIDTH + 1 {1'b0}};
		end
		else if (wen == 1'b1) begin
			waddr <= #(1) waddr_next;
			gcout_reg <= #(1) gcout_next;
		end
	assign gcout = gcout_reg;
	generate
		for (i = 0; i < (ADDR_WIDTH + 1); i = i + 1) begin : genblk1
			assign tmp[i] = ^(gcin >> i);
		end
	endgenerate
	always @(*)
		case (gmode)
			2'h0: raddr_next = {tmp[ADDR_WIDTH - 2:0], 2'b00} & {{ADDR_WIDTH - 1 {1'b1}}, 2'b00};
			2'h1: raddr_next = {tmp[ADDR_WIDTH - 1:0], 1'b0} & {{ADDR_WIDTH {1'b1}}, 1'b0};
			2'h2: raddr_next = {tmp[ADDR_WIDTH:0]} & {ADDR_WIDTH + 1 {1'b1}};
			default: raddr_next = {ADDR_WIDTH + 1 {1'b0}};
		endcase
	assign ff_waddr = waddr[ADDR_WIDTH - 1:0];
	assign pushflags = (rst_n ? {full, fmo, paf, overflow} : 4'b1111);
	assign waddr_next = waddr + (wmode == 2'h0 ? 'h4 : (wmode == 2'h1 ? 'h2 : 'h1));
endmodule
module fifo_pop (
	ren_o,
	popflags,
	out_raddr,
	gcout,
	rst_n,
	rclk,
	ren_in,
	rmode,
	wmode,
	gcin,
	depth,
	upae
);
	parameter ADDR_WIDTH = 11;
	parameter FIFO_WIDTH = 3'd2;
	output wire ren_o;
	output wire [3:0] popflags;
	output reg [ADDR_WIDTH - 1:0] out_raddr;
	output wire [ADDR_WIDTH:0] gcout;
	input rst_n;
	input rclk;
	input ren_in;
	input [1:0] rmode;
	input [1:0] wmode;
	input [ADDR_WIDTH:0] gcin;
	input [ADDR_WIDTH - 1:0] upae;
	input [2:0] depth;
	reg empty;
	reg epo;
	reg pae;
	reg underflow;
	reg e1;
	reg e2;
	reg o1;
	reg o2;
	reg q1;
	reg q2;
	reg [1:0] bwl_sel;
	reg [1:0] gmode;
	reg [ADDR_WIDTH - 1:0] ff_raddr;
	reg [ADDR_WIDTH:0] waddr;
	reg [ADDR_WIDTH:0] raddr;
	reg [ADDR_WIDTH:0] gcout_reg;
	reg [ADDR_WIDTH:0] gcout_next;
	reg [ADDR_WIDTH:0] waddr_next;
	reg [ADDR_WIDTH - 1:0] pae_thresh;
	wire ren_out;
	wire empty_next;
	wire pae_next;
	wire epo_next;
	wire [ADDR_WIDTH - 2:0] gc32out_next;
	wire [ADDR_WIDTH - 1:0] gc16out_next;
	wire [ADDR_WIDTH:0] gc8out_next;
	wire [ADDR_WIDTH:0] raddr_next;
	wire [ADDR_WIDTH - 1:0] ff_raddr_next;
	wire [ADDR_WIDTH:0] tmp;
	wire [ADDR_WIDTH:0] next_count;
	wire [ADDR_WIDTH:0] count;
	reg [ADDR_WIDTH:0] fbytes;
	genvar i;
	assign next_count = waddr - raddr_next;
	assign count = waddr - raddr;
	always @(*)
		case (depth)
			3'b000: fbytes = 'd2048;
			3'b001: fbytes = 'd1024;
			3'b010: fbytes = 'd512;
			3'b011: fbytes = 'd256;
			3'b100: fbytes = 'd128;
			3'b101: fbytes = 'd64;
			3'b110: fbytes = 'd32;
			3'b111: fbytes = 'd4096;
		endcase
	always @(*) pae_thresh = rmode ? (rmode[0] ? upae << 1 : upae) : upae << 2;
	assign ren_out = (empty ? 1'b1 : ren_in);
	always @(*)
		case (rmode)
			2'h0: gmode = 2'h0;
			2'h1: gmode = (wmode == 2'h0 ? 2'h0 : 2'h1);
			2'h2: gmode = (wmode == 2'h2 ? 2'h2 : wmode);
			2'h3: gmode = 2'h3;
		endcase
	always @(*) begin
		e1 = 1'b0;
		e2 = 1'b0;
		o1 = 1'b0;
		o2 = 1'b0;
		q1 = next_count < pae_thresh;
		q2 = count < pae_thresh;
		case (rmode)
			2'h0: begin
				e1 = raddr_next[ADDR_WIDTH:2] == waddr_next[ADDR_WIDTH:2];
				e2 = raddr[ADDR_WIDTH:2] == waddr_next[ADDR_WIDTH:2];
				o1 = (raddr_next[ADDR_WIDTH:2] + 1) == waddr_next[ADDR_WIDTH:2];
				o2 = (raddr[ADDR_WIDTH:2] + 1) == waddr_next[ADDR_WIDTH:2];
			end
			2'h1: begin
				e1 = raddr_next[ADDR_WIDTH:1] == waddr_next[ADDR_WIDTH:1];
				e2 = raddr[ADDR_WIDTH:1] == waddr_next[ADDR_WIDTH:1];
				o1 = (raddr_next[ADDR_WIDTH:1] + 1) == waddr_next[ADDR_WIDTH:1];
				o2 = (raddr[ADDR_WIDTH:1] + 1) == waddr_next[ADDR_WIDTH:1];
			end
			2'h2: begin
				e1 = raddr_next[ADDR_WIDTH:0] == waddr_next[ADDR_WIDTH:0];
				e2 = raddr[ADDR_WIDTH:0] == waddr_next[ADDR_WIDTH:0];
				o1 = (raddr_next[ADDR_WIDTH:0] + 1) == waddr_next[ADDR_WIDTH:0];
				o2 = (raddr[ADDR_WIDTH:0] + 1) == waddr_next[11:0];
			end
			2'h3: begin
				e1 = 1'b0;
				e2 = 1'b0;
				o1 = 1'b0;
				o2 = 1'b0;
			end
		endcase
	end
	assign empty_next = (ren_in & !empty ? e1 : e2);
	assign epo_next = (ren_in & !empty ? o1 : o2);
	assign pae_next = (ren_in & !empty ? q1 : q2);
	always @(posedge rclk or negedge rst_n)
		if (~rst_n) begin
			empty <= #(1) 1'b1;
			pae <= #(1) 1'b1;
			epo <= #(1) 1'b0;
		end
		else begin
			empty <= #(1) empty_next;
			pae <= #(1) pae_next;
			epo <= #(1) epo_next;
		end
	assign gc8out_next = (raddr_next >> 1) ^ raddr_next;
	assign gc16out_next = (raddr_next >> 2) ^ (raddr_next >> 1);
	assign gc32out_next = (raddr_next >> 3) ^ (raddr_next >> 2);
	always @(*)
		if (ren_in)
			case (gmode)
				2'h2: gcout_next = gc8out_next;
				2'h1: gcout_next = {1'b0, gc16out_next};
				2'h0: gcout_next = {2'b00, gc32out_next};
				default: gcout_next = 'h0;
			endcase
		else
			gcout_next = 'h0;
	always @(posedge rclk or negedge rst_n)
		if (~rst_n)
			waddr <= #(1) 12'h000;
		else
			waddr <= #(1) waddr_next;
	always @(posedge rclk or negedge rst_n)
		if (~rst_n) begin
			underflow <= #(1) 1'b0;
			bwl_sel <= #(1) 2'h0;
			gcout_reg <= #(1) 12'h000;
		end
		else if (ren_in) begin
			underflow <= #(1) empty;
			if (!empty) begin
				bwl_sel <= #(1) raddr_next[1:0];
				gcout_reg <= #(1) gcout_next;
			end
		end
	generate
		for (i = 0; i < (ADDR_WIDTH + 1); i = i + 1) begin : genblk1
			assign tmp[i] = ^(gcin >> i);
		end
	endgenerate
	always @(*)
		case (gmode)
			2'h0: waddr_next = {tmp[9:0], 2'b00} & 12'hffc;
			2'h1: waddr_next = {tmp[10:0], 1'b0} & 12'hffe;
			2'h2: waddr_next = {tmp[11:0]} & 12'hfff;
			default: waddr_next = 12'h000;
		endcase
	assign ff_raddr_next = ff_raddr + (rmode == 2'h0 ? 'h4 : (rmode == 2'h1 ? 'h2 : 'h1));
	assign raddr_next = raddr + (rmode == 2'h0 ? 'h4 : (rmode == 2'h1 ? 'h2 : 'h1));
	always @(posedge rclk or negedge rst_n)
		if (~rst_n)
			ff_raddr <= #(1) 1'sb0;
		else if (empty & ~empty_next)
			ff_raddr <= #(1) raddr_next[10:0];
		else if ((ren_in & !empty) & ~empty_next)
			ff_raddr <= #(1) ff_raddr_next;
	always @(posedge rclk or negedge rst_n)
		if (~rst_n)
			raddr <= #(1) 12'h000;
		else if (ren_in & !empty)
			raddr <= #(1) raddr_next;
	always @(*)
		case (FIFO_WIDTH)
			default: out_raddr = ff_raddr[ADDR_WIDTH - 1:0];
			2: out_raddr = {ff_raddr[ADDR_WIDTH - 1:1], bwl_sel[0]};
			4: out_raddr = {ff_raddr[ADDR_WIDTH - 1:2], bwl_sel};
		endcase
	assign ren_o = ren_out;
	assign gcout = gcout_reg;
	assign popflags = {empty, epo, pae, underflow};
endmodule
