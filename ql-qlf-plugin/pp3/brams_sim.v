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

`timescale 1ns / 10ps
module fifo_controller_model (
    Rst_n,
    Push_Clk,
    Pop_Clk,

    Fifo_Push,
    Fifo_Push_Flush,
    Fifo_Full,
    Fifo_Full_Usr,

    Fifo_Pop,
    Fifo_Pop_Flush,
    Fifo_Empty,
    Fifo_Empty_Usr,

    Write_Addr,

    Read_Addr,

    //	 Static Control Signals
    Fifo_Ram_Mode,
    Fifo_Sync_Mode,
    Fifo_Push_Width,
    Fifo_Pop_Width
);



  //************* PPII 4K Parameters **************************//

  parameter MAX_PTR_WIDTH = 12;

  parameter DEPTH1 = (1 << (MAX_PTR_WIDTH - 3));
  parameter DEPTH2 = (1 << (MAX_PTR_WIDTH - 2));
  parameter DEPTH3 = (1 << (MAX_PTR_WIDTH - 1));

  parameter D1_QTR_A = MAX_PTR_WIDTH - 5;
  parameter D2_QTR_A = MAX_PTR_WIDTH - 4;
  parameter D3_QTR_A = MAX_PTR_WIDTH - 3;

  input Rst_n;
  input Push_Clk;
  input Pop_Clk;

  input Fifo_Push;
  input Fifo_Push_Flush;
  output Fifo_Full;
  output [3:0] Fifo_Full_Usr;

  input Fifo_Pop;
  input Fifo_Pop_Flush;
  output Fifo_Empty;
  output [3:0] Fifo_Empty_Usr;

  output [MAX_PTR_WIDTH-2:0] Write_Addr;

  output [MAX_PTR_WIDTH-2:0] Read_Addr;

  input Fifo_Ram_Mode;
  input Fifo_Sync_Mode;
  input [1:0] Fifo_Push_Width;
  input [1:0] Fifo_Pop_Width;

  reg    flush_pop_clk_tf;
  reg    flush_pop2push_clk1;
  reg    flush_push_clk_tf;
  reg    flush_push2pop_clk1;
  reg    pop_local_flush_mask;
  reg    push_flush_tf_pop_clk;
  reg    pop2push_ack1;
  reg    pop2push_ack2;
  reg    push_local_flush_mask;
  reg    pop_flush_tf_push_clk;
  reg    push2pop_ack1;
  reg    push2pop_ack2;

  reg    fifo_full_flag_f;
  reg    [3:0]  Fifo_Full_Usr;

  reg    fifo_empty_flag_f;
  reg    [3:0]  Fifo_Empty_Usr;

  reg    [MAX_PTR_WIDTH-1:0]  push_ptr_push_clk;
  reg    [MAX_PTR_WIDTH-1:0]  pop_ptr_push_clk;
  reg    [MAX_PTR_WIDTH-1:0]  pop_ptr_async;
  reg    [MAX_PTR_WIDTH-1:0]  pop_ptr_pop_clk ;
  reg    [MAX_PTR_WIDTH-1:0]  push_ptr_pop_clk;
  reg    [MAX_PTR_WIDTH-1:0]  push_ptr_async;

  reg    [1:0]  push_ptr_push_clk_mask;
  reg    [1:0]  pop_ptr_pop_clk_mask;

  reg    [MAX_PTR_WIDTH-1:0]  pop_ptr_push_clk_mux;
  reg    [MAX_PTR_WIDTH-1:0]  push_ptr_pop_clk_mux;

  reg    match_room4none;
  reg    match_room4one;
  reg    match_room4half;
  reg    match_room4quart;

  reg    match_all_left;
  reg    match_half_left;
  reg    match_quart_left;

  reg   [MAX_PTR_WIDTH-1:0]   depth1_reg;
  reg   [MAX_PTR_WIDTH-1:0]   depth2_reg;
  reg   [MAX_PTR_WIDTH-1:0]   depth3_reg;


  wire	push_clk_rst;
  wire	push_clk_rst_mux;
  wire	push_flush_done;
  wire	pop_clk_rst;
  wire	pop_clk_rst_mux;
  wire	pop_flush_done;

  wire	push_flush_gated;
  wire	pop_flush_gated;

  wire	[MAX_PTR_WIDTH-2:0] Write_Addr;
  wire	[MAX_PTR_WIDTH-2:0] Read_Addr;

  wire	[MAX_PTR_WIDTH-1:0] push_ptr_push_clk_plus1;
  wire	[MAX_PTR_WIDTH-1:0] next_push_ptr_push_clk;
  wire	[MAX_PTR_WIDTH-1:0] pop_ptr_pop_clk_plus1;
  wire	[MAX_PTR_WIDTH-1:0] next_pop_ptr_pop_clk;
  wire	[MAX_PTR_WIDTH-1:0] next_push_ptr_push_clk_mask;
  wire	[MAX_PTR_WIDTH-1:0] next_pop_ptr_pop_clk_mask;

  wire	[MAX_PTR_WIDTH-1:0] pop_ptr_push_clk_l_shift1;
  wire	[MAX_PTR_WIDTH-1:0] pop_ptr_push_clk_l_shift2;
  wire	[MAX_PTR_WIDTH-1:0] pop_ptr_push_clk_r_shift1;
  wire	[MAX_PTR_WIDTH-1:0] pop_ptr_push_clk_r_shift2;

  wire	[MAX_PTR_WIDTH-1:0] push_ptr_pop_clk_l_shift1;
  wire	[MAX_PTR_WIDTH-1:0] push_ptr_pop_clk_l_shift2;
  wire	[MAX_PTR_WIDTH-1:0] push_ptr_pop_clk_r_shift1;
  wire	[MAX_PTR_WIDTH-1:0] push_ptr_pop_clk_r_shift2;

  wire	[MAX_PTR_WIDTH-1:0] push_diff;
  wire	[MAX_PTR_WIDTH-1:0] push_diff_plus_1;
  wire	[MAX_PTR_WIDTH-1:0] pop_diff;

  wire	match_room4all;
  wire	match_room4eight;

  wire	match_one_left;
  wire	match_one2eight_left;

  integer	depth_sel_push;
  integer depth_sel_pop;

  initial begin
    depth1_reg = DEPTH1;
    depth2_reg = DEPTH2;
    depth3_reg = DEPTH3;
  end

  initial begin
    flush_pop_clk_tf      <= 1'b0;
    push2pop_ack1         <= 1'b0;
    push2pop_ack2         <= 1'b0;
    pop_local_flush_mask  <= 1'b0;
    flush_push2pop_clk1   <= 1'b0;
    push_flush_tf_pop_clk <= 1'b0;
    flush_push_clk_tf     <= 1'b0;
    pop2push_ack1         <= 1'b0;
    pop2push_ack2         <= 1'b0;
    push_local_flush_mask <= 1'b0;
    flush_pop2push_clk1   <= 1'b0;
    pop_flush_tf_push_clk <= 1'b0;
    push_ptr_push_clk     <= 0;
    pop_ptr_push_clk      <= 0;
    pop_ptr_async         <= 0;
    fifo_full_flag_f      <= 0;
    pop_ptr_pop_clk       <= 0;
    push_ptr_pop_clk      <= 0;
    push_ptr_async        <= 0;
    fifo_empty_flag_f     <= 1;
    Fifo_Full_Usr         <= 4'b0001;
    Fifo_Empty_Usr        <= 4'b0000;
  end

  assign Fifo_Full = fifo_full_flag_f;
  assign Fifo_Empty = fifo_empty_flag_f;

  assign Write_Addr = push_ptr_push_clk[MAX_PTR_WIDTH-2:0];
  assign Read_Addr = next_pop_ptr_pop_clk[MAX_PTR_WIDTH-2:0];

  assign push_ptr_push_clk_plus1 = push_ptr_push_clk + 1;
  assign next_push_ptr_push_clk = (Fifo_Push) ? push_ptr_push_clk_plus1 : push_ptr_push_clk;
  assign next_push_ptr_push_clk_mask = {
    (push_ptr_push_clk_mask & next_push_ptr_push_clk[MAX_PTR_WIDTH-1:MAX_PTR_WIDTH-2]),
    next_push_ptr_push_clk[MAX_PTR_WIDTH-3:0]
  };

  assign pop_ptr_pop_clk_plus1 = pop_ptr_pop_clk + 1;
  assign next_pop_ptr_pop_clk = (Fifo_Pop) ? pop_ptr_pop_clk_plus1 : pop_ptr_pop_clk;
  assign next_pop_ptr_pop_clk_mask = {
    (pop_ptr_pop_clk_mask & next_pop_ptr_pop_clk[MAX_PTR_WIDTH-1:MAX_PTR_WIDTH-2]),
    next_pop_ptr_pop_clk[MAX_PTR_WIDTH-3:0]
  };

  assign pop_ptr_push_clk_l_shift1 = {pop_ptr_push_clk[MAX_PTR_WIDTH-2:0], 1'b0};
  assign pop_ptr_push_clk_l_shift2 = {pop_ptr_push_clk[MAX_PTR_WIDTH-3:0], 2'b0};
  assign pop_ptr_push_clk_r_shift1 = {1'b0, pop_ptr_push_clk[MAX_PTR_WIDTH-1:1]};
  assign pop_ptr_push_clk_r_shift2 = {2'b0, pop_ptr_push_clk[MAX_PTR_WIDTH-1:2]};

  assign push_ptr_pop_clk_l_shift1 = {push_ptr_pop_clk[MAX_PTR_WIDTH-2:0], 1'b0};
  assign push_ptr_pop_clk_l_shift2 = {push_ptr_pop_clk[MAX_PTR_WIDTH-3:0], 2'b0};
  assign push_ptr_pop_clk_r_shift1 = {1'b0, push_ptr_pop_clk[MAX_PTR_WIDTH-1:1]};
  assign push_ptr_pop_clk_r_shift2 = {2'b0, push_ptr_pop_clk[MAX_PTR_WIDTH-1:2]};

  assign push_diff = next_push_ptr_push_clk_mask - pop_ptr_push_clk_mux;
  assign push_diff_plus_1 = push_diff + 1;
  assign pop_diff = push_ptr_pop_clk_mux - next_pop_ptr_pop_clk_mask;

  assign match_room4all = ~|push_diff;
  assign	match_room4eight	= ( depth_sel_push == 3 ) ? ( push_diff >= DEPTH3-8 ) : ( depth_sel_push == 2 ) ? ( push_diff >= DEPTH2-8 ) : ( push_diff >= DEPTH1-8 );

  assign match_one_left = (pop_diff == 1);
  assign match_one2eight_left = (pop_diff < 8);

  assign push_flush_gated = Fifo_Push_Flush & ~push_local_flush_mask;
  assign pop_flush_gated = Fifo_Pop_Flush & ~pop_local_flush_mask;

  assign push_clk_rst = flush_pop2push_clk1 ^ pop_flush_tf_push_clk;
  assign pop_clk_rst = flush_push2pop_clk1 ^ push_flush_tf_pop_clk;

  assign pop_flush_done = push2pop_ack1 ^ push2pop_ack2;
  assign push_flush_done = pop2push_ack1 ^ pop2push_ack2;

  assign	push_clk_rst_mux	= ( Fifo_Sync_Mode ) ? ( Fifo_Push_Flush | Fifo_Pop_Flush ) : ( push_flush_gated | push_clk_rst );
  assign	pop_clk_rst_mux		= ( Fifo_Sync_Mode ) ? ( Fifo_Push_Flush | Fifo_Pop_Flush ) : ( pop_flush_gated | ( pop_local_flush_mask & ~pop_flush_done ) | pop_clk_rst );


  reg match_room_at_most63, match_at_most63_left;

  always@( push_diff or push_diff_plus_1 or depth_sel_push or match_room4none or match_room4one )
	begin
    if (depth_sel_push == 1) begin
      match_room4none		<= ( push_diff[D1_QTR_A+2:0] == depth1_reg[D1_QTR_A+2:0] );
      // syao 2/12/2013
      match_room4one		<= ( push_diff_plus_1[D1_QTR_A+2:0] == depth1_reg ) | match_room4none;

      match_room4half		<= ( push_diff[D1_QTR_A+1] == 1'b1 );
      match_room4quart	<= ( push_diff[D1_QTR_A] == 1'b1 );

      match_room_at_most63    <=  push_diff[6];
    end else if (depth_sel_push == 2) begin
      match_room4none		<= ( push_diff[D2_QTR_A+2:0] == depth2_reg[D2_QTR_A+2:0] );
      // syao 2/12/2013
      match_room4one		<= ( push_diff_plus_1[D2_QTR_A+2:0] == depth2_reg ) | match_room4none;

      match_room4half		<= ( push_diff[D2_QTR_A+1] == 1'b1 );
      match_room4quart	<= ( push_diff[D2_QTR_A] == 1'b1 );

      // syao 2/12/2013
      //			match_room_at_most63    <=  push_diff[6];
      match_room_at_most63    <=  &push_diff[7:6];
    end else begin
      match_room4none <= (push_diff == depth3_reg);
      match_room4one <= (push_diff_plus_1 == depth3_reg) | match_room4none;

      match_room4half <= (push_diff[D3_QTR_A+1] == 1'b1);
      match_room4quart <= (push_diff[D3_QTR_A] == 1'b1);

      // syao 2/12/2013
      //			match_room_at_most63	<= &push_diff[7:6];
      match_room_at_most63 <= &push_diff[8:6];
    end
  end



  assign room4_32s = ~push_diff[5];
  assign room4_16s = ~push_diff[4];
  assign room4_8s  = ~push_diff[3];
  assign room4_4s  = ~push_diff[2];
  assign room4_2s  = ~push_diff[1];
  assign room4_1s  = &push_diff[1:0];

  always @(depth_sel_pop or pop_diff) begin
    if (depth_sel_pop == 1) begin
      match_all_left <= (pop_diff[D1_QTR_A+2:0] == depth1_reg[D1_QTR_A+2:0]);

      match_half_left <= (pop_diff[D1_QTR_A+1] == 1'b1);
      match_quart_left <= (pop_diff[D1_QTR_A] == 1'b1);

      match_at_most63_left <= ~pop_diff[6];
    end else if (depth_sel_pop == 2) begin
      match_all_left <= (pop_diff[D2_QTR_A+2:0] == depth2_reg[D2_QTR_A+2:0]);

      match_half_left <= (pop_diff[D2_QTR_A+1] == 1'b1);
      match_quart_left <= (pop_diff[D2_QTR_A] == 1'b1);

      // syao 2/12/2013
      //			match_at_most63_left	<= ~pop_diff[6];			
      match_at_most63_left <= ~|pop_diff[7:6];
    end else begin
      match_all_left <= (pop_diff == depth3_reg);

      match_half_left <= (pop_diff[D3_QTR_A+1] == 1'b1);
      match_quart_left <= (pop_diff[D3_QTR_A] == 1'b1);

      // syao 2/12/2013
      //			match_at_most63_left	<= ~|pop_diff[7:6];			
      match_at_most63_left <= ~|pop_diff[8:6];
    end
  end



  assign at_least_32 = pop_diff[5];
  assign at_least_16 = pop_diff[4];
  assign at_least_8 = pop_diff[3];
  assign at_least_4 = pop_diff[2];
  assign at_least_2 = pop_diff[1];
  assign one_left = pop_diff[0];


  always @(posedge Pop_Clk or negedge Rst_n) begin
    if (~Rst_n) begin
      push2pop_ack1 <= 1'b0;
      push2pop_ack2 <= 1'b0;
      flush_pop_clk_tf <= 1'b0;
      pop_local_flush_mask <= 1'b0;
      flush_push2pop_clk1 <= 1'b0;
      push_flush_tf_pop_clk <= 1'b0;
    end else begin
      push2pop_ack1 <= pop_flush_tf_push_clk;
      push2pop_ack2 <= push2pop_ack1;
      flush_push2pop_clk1 <= flush_push_clk_tf;
      if (pop_flush_gated) begin
        flush_pop_clk_tf <= ~flush_pop_clk_tf;
      end

      if (pop_flush_gated & ~Fifo_Sync_Mode) begin
        pop_local_flush_mask <= 1'b1;
      end else if (pop_flush_done) begin
        pop_local_flush_mask <= 1'b0;
      end

      if (pop_clk_rst) begin
        push_flush_tf_pop_clk <= ~push_flush_tf_pop_clk;
      end
    end
  end

  always @(posedge Push_Clk or negedge Rst_n) begin
    if (~Rst_n) begin
      pop2push_ack1 <= 1'b0;
      pop2push_ack2 <= 1'b0;
      flush_push_clk_tf <= 1'b0;
      push_local_flush_mask <= 1'b0;
      flush_pop2push_clk1 <= 1'b0;
      pop_flush_tf_push_clk <= 1'b0;
    end else begin
      pop2push_ack1				<= push_flush_tf_pop_clk;
      pop2push_ack2				<= pop2push_ack1;
      flush_pop2push_clk1	<= flush_pop_clk_tf;
      if (push_flush_gated) begin
        flush_push_clk_tf <= ~flush_push_clk_tf;
      end

      if (push_flush_gated & ~Fifo_Sync_Mode) begin
        push_local_flush_mask <= 1'b1;
      end else if (push_flush_done) begin
        push_local_flush_mask <= 1'b0;
      end

      if (push_clk_rst) begin
        pop_flush_tf_push_clk <= ~pop_flush_tf_push_clk;
      end
    end
  end

  always@( Fifo_Push_Width or Fifo_Pop_Width or pop_ptr_push_clk_l_shift1 or pop_ptr_push_clk_l_shift2 or pop_ptr_push_clk_r_shift1 or
						pop_ptr_push_clk_r_shift2 or push_ptr_pop_clk_l_shift1 or push_ptr_pop_clk_l_shift2 or push_ptr_pop_clk_r_shift1 or push_ptr_pop_clk_r_shift2 or
						pop_ptr_push_clk or push_ptr_pop_clk )
	begin
    case ({
      Fifo_Push_Width, Fifo_Pop_Width
    })
      4'b0001:	//	byte push halfword pop
      begin
        push_ptr_push_clk_mask <= 2'b11;
        pop_ptr_pop_clk_mask   <= 2'b01;
        pop_ptr_push_clk_mux   <= pop_ptr_push_clk_l_shift1;
        push_ptr_pop_clk_mux   <= push_ptr_pop_clk_r_shift1;
      end
      4'b0010:	//	byte push word pop
      begin
        push_ptr_push_clk_mask <= 2'b11;
        pop_ptr_pop_clk_mask   <= 2'b00;
        pop_ptr_push_clk_mux   <= pop_ptr_push_clk_l_shift2;
        push_ptr_pop_clk_mux   <= push_ptr_pop_clk_r_shift2;
      end
      4'b0100:	//	halfword push byte pop
      begin
        push_ptr_push_clk_mask <= 2'b01;
        pop_ptr_pop_clk_mask   <= 2'b11;
        pop_ptr_push_clk_mux   <= pop_ptr_push_clk_r_shift1;
        push_ptr_pop_clk_mux   <= push_ptr_pop_clk_l_shift1;
      end
      4'b0110:	//	halfword push word pop
      begin
        push_ptr_push_clk_mask <= 2'b11;
        pop_ptr_pop_clk_mask   <= 2'b01;
        pop_ptr_push_clk_mux   <= pop_ptr_push_clk_l_shift1;
        push_ptr_pop_clk_mux   <= push_ptr_pop_clk_r_shift1;
      end
      4'b1000:	//	word push byte pop
      begin
        push_ptr_push_clk_mask <= 2'b00;
        pop_ptr_pop_clk_mask   <= 2'b11;
        pop_ptr_push_clk_mux   <= pop_ptr_push_clk_r_shift2;
        push_ptr_pop_clk_mux   <= push_ptr_pop_clk_l_shift2;
      end
      4'b1001:	//	word push halfword pop
      begin
        push_ptr_push_clk_mask <= 2'b01;
        pop_ptr_pop_clk_mask   <= 2'b11;
        pop_ptr_push_clk_mux   <= pop_ptr_push_clk_r_shift1;
        push_ptr_pop_clk_mux   <= push_ptr_pop_clk_l_shift1;
      end
      default:	//	no conversion
      begin
        push_ptr_push_clk_mask <= 2'b11;
        pop_ptr_pop_clk_mask   <= 2'b11;
        pop_ptr_push_clk_mux   <= pop_ptr_push_clk;
        push_ptr_pop_clk_mux   <= push_ptr_pop_clk;
      end
    endcase
  end

  always @(Fifo_Ram_Mode or Fifo_Push_Width) begin
    if (Fifo_Ram_Mode == Fifo_Push_Width[0]) begin
      depth_sel_push <= 2;
    end else if (Fifo_Ram_Mode == Fifo_Push_Width[1]) begin
      depth_sel_push <= 1;
    end else begin
      depth_sel_push <= 3;
    end
  end

  always @(Fifo_Ram_Mode or Fifo_Pop_Width) begin
    if (Fifo_Ram_Mode == Fifo_Pop_Width[0]) begin
      depth_sel_pop <= 2;
    end else if (Fifo_Ram_Mode == Fifo_Pop_Width[1]) begin
      depth_sel_pop <= 1;
    end else begin
      depth_sel_pop <= 3;
    end
  end

  always @(posedge Push_Clk or negedge Rst_n) begin
    if (~Rst_n) begin
      push_ptr_push_clk <= 0;
      pop_ptr_push_clk <= 0;
      pop_ptr_async <= 0;
      fifo_full_flag_f <= 0;
    end else begin
      if (push_clk_rst_mux) begin
        push_ptr_push_clk <= 0;
        pop_ptr_push_clk <= 0;
        pop_ptr_async <= 0;
        fifo_full_flag_f <= 0;
      end else begin
        push_ptr_push_clk <= next_push_ptr_push_clk;
        pop_ptr_push_clk <= (Fifo_Sync_Mode) ? next_pop_ptr_pop_clk : pop_ptr_async;
        pop_ptr_async <= pop_ptr_pop_clk;
        fifo_full_flag_f <= match_room4one | match_room4none;
      end
    end
  end

  always @(posedge Pop_Clk or negedge Rst_n) begin
    if (~Rst_n) begin
      pop_ptr_pop_clk <= 0;
      push_ptr_pop_clk <= 0;
      push_ptr_async <= 0;
      fifo_empty_flag_f <= 1;
    end else begin
      if (pop_clk_rst_mux) begin
        pop_ptr_pop_clk <= 0;
        push_ptr_pop_clk <= 0;
        push_ptr_async <= 0;
        fifo_empty_flag_f <= 1;
      end else begin
        pop_ptr_pop_clk <= next_pop_ptr_pop_clk;
        push_ptr_pop_clk <= (Fifo_Sync_Mode) ? next_push_ptr_push_clk : push_ptr_async;
        push_ptr_async <= push_ptr_push_clk;
        fifo_empty_flag_f <= (pop_diff == 1) | (pop_diff == 0);
      end
    end
  end

  always @(posedge Push_Clk or negedge Rst_n) begin
    if (~Rst_n) begin

      //based on rtl, this should be full after reset		
      //			Fifo_Full_Usr	<= 4'b1000;
      Fifo_Full_Usr <= 4'b0001;
    end else begin
      if (match_room4none) begin
        Fifo_Full_Usr <= 4'b0000;
      end else if (match_room4all) begin
        Fifo_Full_Usr <= 4'b0001;
      end else if (~match_room4half) begin
        Fifo_Full_Usr <= 4'b0010;
      end else if (~match_room4quart) begin
        Fifo_Full_Usr <= 4'b0011;
      end else begin
        if (match_room_at_most63) begin
          if (room4_32s) Fifo_Full_Usr <= 4'b1010;
          else if (room4_16s) Fifo_Full_Usr <= 4'b1011;
          else if (room4_8s) Fifo_Full_Usr <= 4'b1100;
          else if (room4_4s) Fifo_Full_Usr <= 4'b1101;
          else if (room4_2s) Fifo_Full_Usr <= 4'b1110;
          else if (room4_1s) Fifo_Full_Usr <= 4'b1111;
          else Fifo_Full_Usr <= 4'b1110;
        end else Fifo_Full_Usr <= 4'b0100;
      end
    end
  end

  always @(posedge Pop_Clk or negedge Rst_n) begin
    if (~Rst_n) begin
      Fifo_Empty_Usr <= 4'b0000;
    end else begin
      if (Fifo_Pop_Flush | (pop_local_flush_mask & ~pop_flush_done) | pop_clk_rst) begin
        Fifo_Empty_Usr <= 4'b0000;
      end else if (match_all_left) begin
        Fifo_Empty_Usr <= 4'b1111;
      end else if (match_half_left) begin
        Fifo_Empty_Usr <= 4'b1110;
      end else if (match_quart_left) begin
        Fifo_Empty_Usr <= 4'b1101;
      end else begin
        if (match_at_most63_left) begin
          if (at_least_32) Fifo_Empty_Usr <= 4'b0110;
          else if (at_least_16) Fifo_Empty_Usr <= 4'b0101;
          else if (at_least_8) Fifo_Empty_Usr <= 4'b0100;
          else if (at_least_4) Fifo_Empty_Usr <= 4'b0011;
          else if (at_least_2) Fifo_Empty_Usr <= 4'b0010;
          else if (one_left) Fifo_Empty_Usr <= 4'b0001;
          else Fifo_Empty_Usr <= 4'b0000;
        end else Fifo_Empty_Usr <= 4'b1000;
      end
    end
  end
endmodule

`timescale 10 ps / 1 ps

//`define ADDRWID 8
`define DATAWID 18 
`define WEWID 2
//`define DEPTH 256

module ram (
    AA,
    AB,
    CLKA,
    CLKB,
    WENA,
    WENB,
    CENA,
    CENB,
    WENBA,
    WENBB,
    DA,
    QA,
    DB,
    QB
);


  parameter ADDRWID = 8;
  parameter DEPTH = (1 << ADDRWID);

  parameter [9215:0] INIT = 9216'bx;
  parameter INIT_FILE = "init.mem";
  parameter init_ad = 0;

  parameter data_width_int = 16;
  parameter data_depth_int = 1024;

  output [`DATAWID-1:0] QA;
  input CLKA;
  input CENA;
  input WENA;
  input [`WEWID-1:0] WENBA;
  input [ADDRWID-1:0] AA;
  input [`DATAWID-1:0] DA;
  output [`DATAWID-1:0] QB;

  input CLKB;
  input CENB;
  input WENB;
  input [`WEWID-1:0] WENBB;
  input [ADDRWID-1:0] AB;
  input [`DATAWID-1:0] DB;

  integer i, j, k, l, m, n, o;

  wire                CEN1;
  wire                OEN1;
  wire                WEN1;
  wire [  `WEWID-1:0] WENB1;
  wire [ ADDRWID-1:0] A1;

  reg  [ ADDRWID-1:0] AddrOut1;
  wire [`DATAWID-1:0] I1;

  wire                CEN2;
  wire                OEN2;
  wire                WEN2;
  wire [  `WEWID-1:0] WENB2;
  wire [ ADDRWID-1:0] A2;

  reg  [ ADDRWID-1:0] AddrOut2;
  wire [`DATAWID-1:0] I2;

  reg [`DATAWID-1:0] O1, QAreg;
  reg [`DATAWID-1:0] O2, QBreg;

  reg                 WEN1_f;
  reg                 WEN2_f;
  reg  [ ADDRWID-1:0] A2_f;
  reg  [ ADDRWID-1:0] A1_f;

  wire                CEN1_SEL;
  wire                WEN1_SEL;
  wire [ ADDRWID-1:0] A1_SEL;
  wire [`DATAWID-1:0] I1_SEL;
  wire [  `WEWID-1:0] WENB1_SEL;

  wire                CEN2_SEL;
  wire                WEN2_SEL;
  wire [ ADDRWID-1:0] A2_SEL;
  wire [`DATAWID-1:0] I2_SEL;
  wire [  `WEWID-1:0] WENB2_SEL;
  wire                overlap;

  wire CLKA_d, CLKB_d, CEN1_d, CEN2_d;

  assign	A1_SEL    = AA;
  assign	I1_SEL    = DA;
  assign	CEN1_SEL  = CENA;
  assign	WEN1_SEL  = WENA;
  assign	WENB1_SEL = WENBA;

  assign	A2_SEL    = AB;
  assign	I2_SEL    = DB;
  assign	CEN2_SEL  = CENB;
  assign	WEN2_SEL  = WENB;
  assign	WENB2_SEL = WENBB;

  assign	CEN1	= CEN1_SEL;
  assign	OEN1	= 1'b0;
  assign	WEN1	= WEN1_SEL;
  assign	WENB1	= WENB1_SEL;
  assign	A1		= A1_SEL;
  assign	I1		= I1_SEL;

  assign	CEN2	= CEN2_SEL;
  assign	OEN2	= 1'b0;
  assign	WEN2	= WEN2_SEL;
  assign	WENB2	= WENB2_SEL;
  assign	A2		= A2_SEL;
  assign	I2		= I2_SEL;

  //assign	QA	= O1;
  //assign	QB	= O2;

  reg [`DATAWID-1:0] ram[DEPTH-1:0];
  reg [data_width_int-1 : 0] ram_dum[data_depth_int-1:0];
  reg [`DATAWID-1:0] wrData1;
  reg [`DATAWID-1:0] wrData2;
  wire [`DATAWID-1:0] tmpData1;
  wire [`DATAWID-1:0] tmpData2;

  reg CENreg1, CENreg2;

  assign #1 CLKA_d = CLKA;
  assign #1 CLKB_d = CLKB;
  // updated by sya 20130523
  assign #2 CEN1_d = CEN1;
  assign #2 CEN2_d = CEN2;

  assign QA = QAreg | O1;
  assign QB = QBreg | O2;

  assign tmpData1 = ram[A1];
  assign tmpData2 = ram[A2];

  assign overlap = (A1_f == A2_f) & WEN1_f & WEN2_f;

  initial begin
`ifndef YOSYS
    $readmemh(INIT_FILE, ram_dum);
`endif
    #10 n = 0;
    o = 0;
    for (i = 0; i < DEPTH; i = i + 1) begin
      if (data_width_int > 16)
        ram[i] <= {
          1'b0,
          ram_dum[i][((16*init_ad)+16)-1:((16*init_ad)+8)],
          1'b0,
          ram_dum[i][((16*init_ad)+8)-1:(16*init_ad)]
        };
      else if (data_width_int <= 8 && data_depth_int <= 1024)
        ram[i] <= {
          1'b0, ram_dum[i+n+1+(1024*init_ad)][7:0], 1'b0, ram_dum[i+n+(1024*init_ad)][7:0]
        };
      else if (data_width_int <= 8 && data_depth_int > 1024)
        ram[i] <= {1'b0, ram_dum[i+o+init_ad+1][7:0], 1'b0, ram_dum[i+o+init_ad][7:0]};
      else if (data_width_int > 8 && data_width_int <= 16 && data_depth_int > 512)
        ram[i] <= {1'b0, ram_dum[i+n+init_ad][15:8], 1'b0, ram_dum[i+n+init_ad][7:0]};
      else ram[i] <= {1'b0, ram_dum[i+(512*init_ad)][15:8], 1'b0, ram_dum[i+(512*init_ad)][7:0]};

      n = n + 1;
      o = o + 3;
    end
  end

  always @(WENB1 or I1 or tmpData1) begin
    for (j = 0; j < 9; j = j + 1) begin
      wrData1[j] <= (WENB1[0]) ? tmpData1[j] : I1[j];
    end
    for (l = 9; l < 19; l = l + 1) begin
      wrData1[l] <= (WENB1[1]) ? tmpData1[l] : I1[l];
    end
  end

  always @(posedge CLKA) begin
    if (~WEN1 & ~CEN1) begin
      ram[A1] <= wrData1[`DATAWID-1:0];
    end
  end

  //pre-charging to 1 every clock cycle
  always @(posedge CLKA_d)
    if (~CEN1_d) begin
      O1 = 18'h3ffff;
      #100;
      O1 = 18'h00000;
    end


  always @(posedge CLKA)
    if (~CEN1) begin
      AddrOut1 <= A1;
    end

  always @(posedge CLKA_d)
    if (~CEN1_d) begin
      QAreg <= ram[AddrOut1];
    end


  always @(posedge CLKA) begin
    WEN1_f <= ~WEN1 & ~CEN1;
    A1_f   <= A1;

  end

  always @(WENB2 or I2 or tmpData2) begin
    for (k = 0; k < 9; k = k + 1) begin
      wrData2[k] <= (WENB2[0]) ? tmpData2[k] : I2[k];
    end
    for (m = 9; m < 19; m = m + 1) begin
      wrData2[m] <= (WENB2[1]) ? tmpData2[m] : I2[m];
    end
  end

  always @(posedge CLKB) begin
    if (~WEN2 & ~CEN2) begin
      ram[A2] <= wrData2[`DATAWID-1:0];
    end
  end

  //pre-charging to 1 every clock cycle
  always @(posedge CLKB_d)
    if (~CEN2_d) begin
      O2 = 18'h3ffff;
      #100;
      O2 = 18'h00000;
    end

  always @(posedge CLKB)
    if (~CEN2) begin
      AddrOut2 <= A2;
    end

  always @(posedge CLKB_d)
    if (~CEN2_d) begin
      QBreg <= ram[AddrOut2];
    end

  always @(posedge CLKB) begin
    WEN2_f <= ~WEN2 & ~CEN2;
    A2_f   <= A2;

  end

  always @(A1_f or A2_f or overlap) begin
    if (overlap) begin
      ram[A1_f] <= 18'bxxxxxxxxxxxxxxxxxx;
    end
  end

endmodule

`timescale 1 ns / 10 ps
//`define ADDRWID 10
`define DATAWID 18
`define WEWID 2

module x2_model (
    Concat_En,

    ram0_WIDTH_SELA,
    ram0_WIDTH_SELB,
    ram0_PLRD,

    ram0_CEA,
    ram0_CEB,
    ram0_I,
    ram0_O,
    ram0_AA,
    ram0_AB,
    ram0_CSBA,
    ram0_CSBB,
    ram0_WENBA,

    ram1_WIDTH_SELA,
    ram1_WIDTH_SELB,
    ram1_PLRD,

    ram1_CEA,
    ram1_CEB,
    ram1_I,
    ram1_O,
    ram1_AA,
    ram1_AB,
    ram1_CSBA,
    ram1_CSBB,
    ram1_WENBA
);

  parameter ADDRWID = 10;
  parameter [18431:0] INIT = 18432'bx;
  parameter INIT_FILE = "init.mem";
  parameter data_width_int = 16;
  parameter data_depth_int = 1024;
  parameter init_ad1 = 0;
  parameter init_ad2 = (data_depth_int > 1024) ? 2 : 1;


  input Concat_En;

  input [1:0] ram0_WIDTH_SELA;
  input [1:0] ram0_WIDTH_SELB;
  input ram0_PLRD;
  input ram0_CEA;
  input ram0_CEB;
  input [`DATAWID-1:0] ram0_I;
  output [`DATAWID-1:0] ram0_O;
  input [ADDRWID-1:0] ram0_AA;
  input [ADDRWID-1:0] ram0_AB;
  input ram0_CSBA;
  input ram0_CSBB;
  input [`WEWID-1:0] ram0_WENBA;

  input [1:0] ram1_WIDTH_SELA;
  input [1:0] ram1_WIDTH_SELB;
  input ram1_PLRD;
  input ram1_CEA;
  input ram1_CEB;
  input [`DATAWID-1:0] ram1_I;
  output [`DATAWID-1:0] ram1_O;
  input [ADDRWID-1:0] ram1_AA;
  input [ADDRWID-1:0] ram1_AB;
  input ram1_CSBA;
  input ram1_CSBB;
  input [`WEWID-1:0] ram1_WENBA;

  reg                 ram0_PLRDA_SEL;
  reg                 ram0_PLRDB_SEL;
  reg                 ram1_PLRDA_SEL;
  reg                 ram1_PLRDB_SEL;
  reg                 ram_AA_ram_SEL;
  reg                 ram_AB_ram_SEL;

  reg  [  `WEWID-1:0] ram0_WENBA_SEL;
  reg  [  `WEWID-1:0] ram0_WENBB_SEL;
  reg  [  `WEWID-1:0] ram1_WENBA_SEL;
  reg  [  `WEWID-1:0] ram1_WENBB_SEL;

  reg                 ram0_A_x9_SEL;
  reg                 ram0_B_x9_SEL;
  reg                 ram1_A_x9_SEL;
  reg                 ram1_B_x9_SEL;

  reg  [ ADDRWID-3:0] ram0_AA_SEL;
  reg  [ ADDRWID-3:0] ram0_AB_SEL;
  reg  [ ADDRWID-3:0] ram1_AA_SEL;
  reg  [ ADDRWID-3:0] ram1_AB_SEL;

  reg                 ram0_AA_byte_SEL;
  reg                 ram0_AB_byte_SEL;
  reg                 ram1_AA_byte_SEL;
  reg                 ram1_AB_byte_SEL;

  reg                 ram0_AA_byte_SEL_Q;
  reg                 ram0_AB_byte_SEL_Q;
  reg                 ram1_AA_byte_SEL_Q;
  reg                 ram1_AB_byte_SEL_Q;
  reg                 ram0_A_mux_ctl_Q;
  reg                 ram0_B_mux_ctl_Q;
  reg                 ram1_A_mux_ctl_Q;
  reg                 ram1_B_mux_ctl_Q;

  reg                 ram0_O_mux_ctrl_Q;
  reg                 ram1_O_mux_ctrl_Q;

  reg                 ram_AA_ram_SEL_Q;
  reg                 ram_AB_ram_SEL_Q;

  wire [`DATAWID-1:0] QA_1_SEL3;
  wire [`DATAWID-1:0] QB_0_SEL2;
  wire [`DATAWID-1:0] QB_1_SEL2;

  reg  [`DATAWID-1:0] QA_0_Q;
  reg  [`DATAWID-1:0] QB_0_Q;
  reg  [`DATAWID-1:0] QA_1_Q;
  reg  [`DATAWID-1:0] QB_1_Q;

  wire [`DATAWID-1:0] QA_0;
  wire [`DATAWID-1:0] QB_0;
  wire [`DATAWID-1:0] QA_1;
  wire [`DATAWID-1:0] QB_1;

  wire                ram0_CSBA_SEL;
  wire                ram0_CSBB_SEL;
  wire                ram1_CSBA_SEL;
  wire                ram1_CSBB_SEL;

  wire [`DATAWID-1:0] ram0_I_SEL1;
  wire [`DATAWID-1:0] ram1_I_SEL1;

  wire                dual_port;

  wire                ram0_WEBA_SEL;
  wire                ram0_WEBB_SEL;
  wire                ram1_WEBA_SEL;
  wire                ram1_WEBB_SEL;

  wire [`DATAWID-1:0] ram1_I_SEL2;

  wire [`DATAWID-1:0] QA_1_SEL2;
  wire [`DATAWID-1:0] QA_0_SEL1;
  wire [`DATAWID-1:0] QB_0_SEL1;
  wire [`DATAWID-1:0] QA_1_SEL1;
  wire [`DATAWID-1:0] QB_1_SEL1;

  wire [`DATAWID-1:0] QB_0_SEL3;
  wire [`DATAWID-1:0] QA_0_SEL2;

  initial begin
    QA_0_Q             <= 0;
    QB_0_Q             <= 0;
    QA_1_Q             <= 0;
    QB_1_Q             <= 0;
    ram0_AA_byte_SEL_Q <= 0;
    ram0_A_mux_ctl_Q   <= 0;
    ram0_AB_byte_SEL_Q <= 0;
    ram0_B_mux_ctl_Q   <= 0;
    ram1_AA_byte_SEL_Q <= 0;
    ram1_A_mux_ctl_Q   <= 0;
    ram1_AB_byte_SEL_Q <= 0;
    ram1_B_mux_ctl_Q   <= 0;
    ram_AA_ram_SEL_Q   <= 0;
    ram1_O_mux_ctrl_Q  <= 0;
    ram_AB_ram_SEL_Q   <= 0;
    ram0_O_mux_ctrl_Q  <= 0;
  end

  assign dual_port = Concat_En & ~(ram0_WIDTH_SELA[1] | ram0_WIDTH_SELB[1]);

  assign ram0_CSBA_SEL = ram0_CSBA;
  assign ram0_CSBB_SEL = ram0_CSBB;
  assign ram1_CSBA_SEL = Concat_En ? ram0_CSBA : ram1_CSBA;
  assign ram1_CSBB_SEL = Concat_En ? ram0_CSBB : ram1_CSBB;

  assign ram0_O = QB_0_SEL3;
  assign ram1_O = dual_port ? QA_1_SEL3 : QB_1_SEL2;

  assign ram0_I_SEL1[8:0] = ram0_I[8:0];
  assign ram1_I_SEL1[8:0] = ram1_I[8:0];
  assign ram0_I_SEL1[17:9] = ram0_AA_byte_SEL ? ram0_I[8:0] : ram0_I[17:9];
  assign ram1_I_SEL1[17:9]	= ( ( ~Concat_En & ram1_AA_byte_SEL ) | ( dual_port & ram0_AB_byte_SEL ) ) ? ram1_I[8:0] : ram1_I[17:9];

  assign ram1_I_SEL2 = (Concat_En & ~ram0_WIDTH_SELA[1]) ? ram0_I_SEL1 : ram1_I_SEL1;

  assign ram0_WEBA_SEL = &ram0_WENBA_SEL;
  assign ram0_WEBB_SEL = &ram0_WENBB_SEL;
  assign ram1_WEBA_SEL = &ram1_WENBA_SEL;
  assign ram1_WEBB_SEL = &ram1_WENBB_SEL;

  assign QA_0_SEL1 = (ram0_PLRDA_SEL) ? QA_0_Q : QA_0;
  assign QB_0_SEL1 = (ram0_PLRDB_SEL) ? QB_0_Q : QB_0;
  assign QA_1_SEL1 = (ram1_PLRDA_SEL) ? QA_1_Q : QA_1;
  assign QB_1_SEL1 = (ram1_PLRDB_SEL) ? QB_1_Q : QB_1;

  assign QA_1_SEL3 = ram1_O_mux_ctrl_Q ? QA_1_SEL2 : QA_0_SEL2;

  assign QA_0_SEL2[8:0] = ram0_A_mux_ctl_Q ? QA_0_SEL1[17:9] : QA_0_SEL1[8:0];
  assign QB_0_SEL2[8:0] = ram0_B_mux_ctl_Q ? QB_0_SEL1[17:9] : QB_0_SEL1[8:0];
  assign QA_1_SEL2[8:0] = ram1_A_mux_ctl_Q ? QA_1_SEL1[17:9] : QA_1_SEL1[8:0];
  assign QB_1_SEL2[8:0] = ram1_B_mux_ctl_Q ? QB_1_SEL1[17:9] : QB_1_SEL1[8:0];

  assign QA_0_SEL2[17:9] = QA_0_SEL1[17:9];
  assign QB_0_SEL2[17:9] = QB_0_SEL1[17:9];
  assign QA_1_SEL2[17:9] = QA_1_SEL1[17:9];
  assign QB_1_SEL2[17:9] = QB_1_SEL1[17:9];

  assign QB_0_SEL3 = ram0_O_mux_ctrl_Q ? QB_1_SEL2 : QB_0_SEL2;

  always @(posedge ram0_CEA) begin
    QA_0_Q <= QA_0;
  end
  always @(posedge ram0_CEB) begin
    QB_0_Q <= QB_0;
  end
  always @(posedge ram1_CEA) begin
    QA_1_Q <= QA_1;
  end
  always @(posedge ram1_CEB) begin
    QB_1_Q <= QB_1;
  end

  always @(posedge ram0_CEA) begin
    if (ram0_CSBA_SEL == 0) ram0_AA_byte_SEL_Q <= ram0_AA_byte_SEL;
    if (ram0_PLRDA_SEL || (ram0_CSBA_SEL == 0))
      ram0_A_mux_ctl_Q <= ram0_A_x9_SEL & (ram0_PLRDA_SEL ? ram0_AA_byte_SEL_Q : ram0_AA_byte_SEL);
  end

  always @(posedge ram0_CEB) begin
    if (ram0_CSBB_SEL == 0) ram0_AB_byte_SEL_Q <= ram0_AB_byte_SEL;
    if (ram0_PLRDB_SEL || (ram0_CSBB_SEL == 0))
      ram0_B_mux_ctl_Q <= ram0_B_x9_SEL & (ram0_PLRDB_SEL ? ram0_AB_byte_SEL_Q : ram0_AB_byte_SEL);
  end

  always @(posedge ram1_CEA) begin
    if (ram1_CSBA_SEL == 0) ram1_AA_byte_SEL_Q <= ram1_AA_byte_SEL;
    if (ram1_PLRDA_SEL || (ram1_CSBA_SEL == 0))
      ram1_A_mux_ctl_Q <= ram1_A_x9_SEL & (ram1_PLRDA_SEL ? ram1_AA_byte_SEL_Q : ram1_AA_byte_SEL);
  end

  always @(posedge ram1_CEB) begin
    if (ram1_CSBB_SEL == 0) ram1_AB_byte_SEL_Q <= ram1_AB_byte_SEL;
    if (ram1_PLRDB_SEL || (ram1_CSBB_SEL == 0))
      ram1_B_mux_ctl_Q <= ram1_B_x9_SEL & (ram1_PLRDB_SEL ? ram1_AB_byte_SEL_Q : ram1_AB_byte_SEL);
  end

  always @(posedge ram0_CEA) begin
    ram_AA_ram_SEL_Q  <= ram_AA_ram_SEL;
    ram1_O_mux_ctrl_Q <= (ram0_PLRDA_SEL ? ram_AA_ram_SEL_Q : ram_AA_ram_SEL);
  end

  always @(posedge ram0_CEB) begin
    ram_AB_ram_SEL_Q  <= ram_AB_ram_SEL;
    ram0_O_mux_ctrl_Q <= (ram0_PLRDB_SEL ? ram_AB_ram_SEL_Q : ram_AB_ram_SEL);
  end

  always@( Concat_En or ram0_WIDTH_SELA or ram0_WIDTH_SELB or ram0_AA or ram0_AB or ram0_WENBA or 
	         ram1_AA or ram1_AB or ram1_WENBA or ram0_PLRD or ram1_PLRD or ram1_WIDTH_SELA or ram1_WIDTH_SELB ) 
	begin
    ram0_A_x9_SEL <= (~|ram0_WIDTH_SELA);
    ram1_A_x9_SEL <= (~|ram0_WIDTH_SELA);
    ram0_B_x9_SEL <= (~|ram0_WIDTH_SELB);
    ram0_AA_byte_SEL <= ram0_AA[0] & (~|ram0_WIDTH_SELA);
    ram0_AB_byte_SEL <= ram0_AB[0] & (~|ram0_WIDTH_SELB);
    if (~Concat_En) begin
      ram_AA_ram_SEL	<= 1'b0;
      ram_AB_ram_SEL	<= 1'b0;
      ram1_B_x9_SEL		<= ( ~|ram1_WIDTH_SELB );

      ram0_PLRDA_SEL	<= ram0_PLRD;
      ram0_PLRDB_SEL	<= ram0_PLRD;
      ram1_PLRDA_SEL	<= ram1_PLRD;
      ram1_PLRDB_SEL	<= ram1_PLRD;
      ram0_WENBB_SEL	<= {`WEWID{1'b1}};
      ram1_WENBB_SEL	<= {`WEWID{1'b1}};

      ram0_AA_SEL				<= ram0_AA >> ( ~|ram0_WIDTH_SELA );
      ram0_WENBA_SEL[0]	<= ( ram0_AA[0] & ( ~|ram0_WIDTH_SELA ) ) | ram0_WENBA[0];
      ram0_WENBA_SEL[1]	<= ( ~ram0_AA[0] & ( ~|ram0_WIDTH_SELA ) ) | ram0_WENBA[( |ram0_WIDTH_SELA )];
      ram0_AB_SEL				<= ram0_AB >> ( ~|ram0_WIDTH_SELB );

      ram1_AA_SEL				<= ram1_AA >> ( ~|ram1_WIDTH_SELA );
      ram1_AA_byte_SEL	<= ram1_AA[0] & ( ~|ram1_WIDTH_SELA );
      ram1_WENBA_SEL[0]	<= ( ram1_AA[0] & ( ~|ram1_WIDTH_SELA ) ) | ram1_WENBA[0];
      ram1_WENBA_SEL[1]	<= ( ~ram1_AA[0] & ( ~|ram1_WIDTH_SELA ) ) | ram1_WENBA[( |ram1_WIDTH_SELA )];
      ram1_AB_SEL				<= ram1_AB >> ( ~|ram1_WIDTH_SELB );
      ram1_AB_byte_SEL	<= ram1_AB[0] & ( ~|ram1_WIDTH_SELB );
    end else begin
      ram_AA_ram_SEL <= ~ram0_WIDTH_SELA[1] & ram0_AA[~ram0_WIDTH_SELA[0]];
      ram_AB_ram_SEL <= ~ram0_WIDTH_SELB[1] & ram0_AB[~ram0_WIDTH_SELB[0]];
      ram1_B_x9_SEL <= (~|ram0_WIDTH_SELB);

      ram0_PLRDA_SEL <= ram1_PLRD;
      ram1_PLRDA_SEL <= ram1_PLRD;
      ram0_PLRDB_SEL <= ram0_PLRD;
      ram1_PLRDB_SEL <= ram0_PLRD;

      ram0_AA_SEL <= ram0_AA >> {
        ~ram0_WIDTH_SELA[1] & ~(ram0_WIDTH_SELA[1] ^ ram0_WIDTH_SELA[0]),
        ~ram0_WIDTH_SELA[1] & ram0_WIDTH_SELA[0]
      };
      ram1_AA_SEL <= ram0_AA >> {
        ~ram0_WIDTH_SELA[1] & ~(ram0_WIDTH_SELA[1] ^ ram0_WIDTH_SELA[0]),
        ~ram0_WIDTH_SELA[1] & ram0_WIDTH_SELA[0]
      };
      ram1_AA_byte_SEL <= ram0_AA[0] & (~|ram0_WIDTH_SELA);
      ram0_WENBA_SEL[0]	<= ram0_WENBA[0] | ( ~ram0_WIDTH_SELA[1] & ( ram0_AA[0] | ( ~ram0_WIDTH_SELA[0] & ram0_AA[1] ) ) );
      ram0_WENBA_SEL[1]	<= ( ( ~|ram0_WIDTH_SELA & ram0_WENBA[0] ) | ( |ram0_WIDTH_SELA & ram0_WENBA[1] ) ) | ( ~ram0_WIDTH_SELA[1] & ( ( ram0_WIDTH_SELA[0] & ram0_AA[0] ) | ( ~ram0_WIDTH_SELA[0] & ~ram0_AA[0] ) | ( ~ram0_WIDTH_SELA[0] & ram0_AA[1] ) ) );

      ram1_WENBA_SEL[0]	<= ( ( ~ram0_WIDTH_SELA[1] & ram0_WENBA[0] ) | ( ram0_WIDTH_SELA[1] & ram1_WENBA[0] ) ) | ( ~ram0_WIDTH_SELA[1] & ( ( ram0_WIDTH_SELA[0] & ~ram0_AA[0] ) | ( ~ram0_WIDTH_SELA[0] & ram0_AA[0] ) | ( ~ram0_WIDTH_SELA[0] & ~ram0_AA[1] ) ) );
      ram1_WENBA_SEL[1]	<= ( ( ( ram0_WIDTH_SELA == 2'b00 ) & ram0_WENBA[0] ) | ( ( ram0_WIDTH_SELA[1] == 1'b1 ) & ram1_WENBA[1] ) | ( ( ram0_WIDTH_SELA == 2'b01 ) & ram0_WENBA[1] ) ) | ( ~ram0_WIDTH_SELA[1] & ( ~ram0_AA[0] | ( ~ram0_WIDTH_SELA[0] & ~ram0_AA[1] ) ) );

      ram0_AB_SEL <= ram0_AB >> {
        ~ram0_WIDTH_SELB[1] & ~(ram0_WIDTH_SELB[1] ^ ram0_WIDTH_SELB[0]),
        ~ram0_WIDTH_SELB[1] & ram0_WIDTH_SELB[0]
      };
      ram1_AB_SEL <= ram0_AB >> {
        ~ram0_WIDTH_SELB[1] & ~(ram0_WIDTH_SELB[1] ^ ram0_WIDTH_SELB[0]),
        ~ram0_WIDTH_SELB[1] & ram0_WIDTH_SELB[0]
      };
      ram1_AB_byte_SEL <= ram0_AB[0] & (~|ram0_WIDTH_SELB);
      ram0_WENBB_SEL[0]	<= ram0_WIDTH_SELB[1] | ( ram0_WIDTH_SELA[1] | ram1_WENBA[0] | ( ram0_AB[0] | ( ~ram0_WIDTH_SELB[0] & ram0_AB[1] ) ) );
      ram0_WENBB_SEL[1]	<= ram0_WIDTH_SELB[1] | ( ram0_WIDTH_SELA[1] | ( ( ~|ram0_WIDTH_SELB & ram1_WENBA[0] ) | ( |ram0_WIDTH_SELB & ram1_WENBA[1] ) ) | ( ( ram0_WIDTH_SELB[0] & ram0_AB[0] ) | ( ~ram0_WIDTH_SELB[0] & ~ram0_AB[0] ) | ( ~ram0_WIDTH_SELB[0] & ram0_AB[1] ) ) );
      ram1_WENBB_SEL[0]	<= ram0_WIDTH_SELB[1] | ( ram0_WIDTH_SELA[1] | ram1_WENBA[0] | ( ( ram0_WIDTH_SELB[0] & ~ram0_AB[0] ) | ( ~ram0_WIDTH_SELB[0] & ram0_AB[0] ) | ( ~ram0_WIDTH_SELB[0] & ~ram0_AB[1] ) ) );
      ram1_WENBB_SEL[1]	<= ram0_WIDTH_SELB[1] | ( ram0_WIDTH_SELA[1] | ( ( ~|ram0_WIDTH_SELB & ram1_WENBA[0] ) | ( |ram0_WIDTH_SELB & ram1_WENBA[1] ) ) | ( ~ram0_AB[0] | ( ~ram0_WIDTH_SELB[0] & ~ram0_AB[1] ) ) );
    end
  end

  ram #(
      .ADDRWID(ADDRWID - 2),
      .INIT(INIT[0*9216+:9216]),
      .INIT_FILE(INIT_FILE),
      .data_width_int(data_width_int),
      .data_depth_int(data_depth_int),
      .init_ad(init_ad1)
  ) ram0_inst (
      .AA(ram0_AA_SEL),
      .AB(ram0_AB_SEL),
      .CLKA(ram0_CEA),
      .CLKB(ram0_CEB),
      .WENA(ram0_WEBA_SEL),
      .WENB(ram0_WEBB_SEL),
      .CENA(ram0_CSBA_SEL),
      .CENB(ram0_CSBB_SEL),
      .WENBA(ram0_WENBA_SEL),
      .WENBB(ram0_WENBB_SEL),
      .DA(ram0_I_SEL1),
      .QA(QA_0),
      .DB(ram1_I_SEL1),
      .QB(QB_0)
  );

  ram #(
      .ADDRWID(ADDRWID - 2),
      .INIT(INIT[1*9216+:9216]),
      .INIT_FILE(INIT_FILE),
      .data_width_int(data_width_int),
      .data_depth_int(data_depth_int),
      .init_ad(init_ad2)
  ) ram1_inst (
      .AA(ram1_AA_SEL),
      .AB(ram1_AB_SEL),
      .CLKA(ram1_CEA),
      .CLKB(ram1_CEB),
      .WENA(ram1_WEBA_SEL),
      .WENB(ram1_WEBB_SEL),
      .CENA(ram1_CSBA_SEL),
      .CENB(ram1_CSBB_SEL),
      .WENBA(ram1_WENBA_SEL),
      .WENBB(ram1_WENBB_SEL),
      .DA(ram1_I_SEL2),
      .QA(QA_1),
      .DB(ram1_I_SEL1),
      .QB(QB_1)
  );

endmodule

`timescale 1 ns / 10 ps
`define ADDRWID 11
`define DATAWID 18
`define WEWID 2

module ram_block_8K (
    CLK1_0,
    CLK2_0,
    WD_0,
    RD_0,
    A1_0,
    A2_0,
    CS1_0,
    CS2_0,
    WEN1_0,
    POP_0,
    Almost_Full_0,
    Almost_Empty_0,
    PUSH_FLAG_0,
    POP_FLAG_0,

    FIFO_EN_0,
    SYNC_FIFO_0,
    PIPELINE_RD_0,
    WIDTH_SELECT1_0,
    WIDTH_SELECT2_0,

    CLK1_1,
    CLK2_1,
    WD_1,
    RD_1,
    A1_1,
    A2_1,
    CS1_1,
    CS2_1,
    WEN1_1,
    POP_1,
    Almost_Empty_1,
    Almost_Full_1,
    PUSH_FLAG_1,
    POP_FLAG_1,

    FIFO_EN_1,
    SYNC_FIFO_1,
    PIPELINE_RD_1,
    WIDTH_SELECT1_1,
    WIDTH_SELECT2_1,

    CONCAT_EN_0,
    CONCAT_EN_1,

    PUSH_0,
    PUSH_1,
    aFlushN_0,
    aFlushN_1
);

  parameter [18431:0] INIT = 18432'bx;
  parameter INIT_FILE = "init.mem";
  parameter data_width_int = 16;
  parameter data_depth_int = 1024;

  input CLK1_0;
  input CLK2_0;
  input [`DATAWID-1:0] WD_0;
  output [`DATAWID-1:0] RD_0;
  input [`ADDRWID-1:0] A1_0;  //chnge
  input [`ADDRWID-1:0] A2_0;  //chnge
  input CS1_0;
  input CS2_0;
  input [`WEWID-1:0] WEN1_0;
  input POP_0;
  output Almost_Full_0;
  output Almost_Empty_0;
  output [3:0] PUSH_FLAG_0;
  output [3:0] POP_FLAG_0;
  input FIFO_EN_0;
  input SYNC_FIFO_0;
  input PIPELINE_RD_0;
  input [1:0] WIDTH_SELECT1_0;
  input [1:0] WIDTH_SELECT2_0;

  input CLK1_1;
  input CLK2_1;
  input [`DATAWID-1:0] WD_1;
  output [`DATAWID-1:0] RD_1;
  input [`ADDRWID-1:0] A1_1;  //chnge
  input [`ADDRWID-1:0] A2_1;  //chnge
  input CS1_1;
  input CS2_1;
  input [`WEWID-1:0] WEN1_1;
  input POP_1;
  output Almost_Full_1;
  output Almost_Empty_1;
  output [3:0] PUSH_FLAG_1;
  output [3:0] POP_FLAG_1;
  input FIFO_EN_1;
  input SYNC_FIFO_1;
  input PIPELINE_RD_1;
  input [1:0] WIDTH_SELECT1_1;
  input [1:0] WIDTH_SELECT2_1;

  input CONCAT_EN_0;
  input CONCAT_EN_1;


  input PUSH_0;
  input PUSH_1;
  input aFlushN_0;
  input aFlushN_1;

  reg                 rstn;

  wire [  `WEWID-1:0] RAM0_WENb1_SEL;
  wire [  `WEWID-1:0] RAM1_WENb1_SEL;

  wire                RAM0_CS1_SEL;
  wire                RAM0_CS2_SEL;
  wire                RAM1_CS1_SEL;
  wire                RAM1_CS2_SEL;

  wire [`ADDRWID-1:0] Fifo0_Write_Addr;
  wire [`ADDRWID-1:0] Fifo0_Read_Addr;

  wire [`ADDRWID-1:0] Fifo1_Write_Addr;
  wire [`ADDRWID-1:0] Fifo1_Read_Addr;

  wire [`ADDRWID-1:0] RAM0_AA_SEL;
  wire [`ADDRWID-1:0] RAM0_AB_SEL;
  wire [`ADDRWID-1:0] RAM1_AA_SEL;
  wire [`ADDRWID-1:0] RAM1_AB_SEL;

  wire                Concat_En_SEL;

  //  To simulate POR
  initial begin
    rstn = 1'b0;
    #30 rstn = 1'b1;
  end

  assign fifo0_rstn = rstn & aFlushN_0;
  assign fifo1_rstn = rstn & aFlushN_1;

  assign Concat_En_SEL = (CONCAT_EN_0 | WIDTH_SELECT1_0[1] | WIDTH_SELECT2_0[1]) ? 1'b1 : 1'b0;

  assign RAM0_AA_SEL = FIFO_EN_0 ? Fifo0_Write_Addr : A1_0[`ADDRWID-1:0];
  assign RAM0_AB_SEL = FIFO_EN_0 ? Fifo0_Read_Addr : A2_0[`ADDRWID-1:0];
  assign RAM1_AA_SEL = FIFO_EN_1 ? Fifo1_Write_Addr : A1_1[`ADDRWID-1:0];
  assign RAM1_AB_SEL = FIFO_EN_1 ? Fifo1_Read_Addr : A2_1[`ADDRWID-1:0];

  assign RAM0_WENb1_SEL = FIFO_EN_0 ? {`WEWID{~PUSH_0}} : ~WEN1_0;
  assign RAM1_WENb1_SEL = ( FIFO_EN_1 & ~Concat_En_SEL ) ? { `WEWID{ ~PUSH_1 } } :
                          ( ( FIFO_EN_0 &  Concat_En_SEL ) ? ( WIDTH_SELECT1_0[1] ? { `WEWID{ ~PUSH_0 } } : { `WEWID{ 1'b1 } } ) : ~WEN1_1 );

  assign RAM0_CS1_SEL = (FIFO_EN_0 ? CS1_0 : ~CS1_0);
  assign RAM0_CS2_SEL = (FIFO_EN_0 ? CS2_0 : ~CS2_0);
  assign RAM1_CS1_SEL = (FIFO_EN_1 ? CS1_1 : ~CS1_1);
  assign RAM1_CS2_SEL = (FIFO_EN_1 ? CS2_1 : ~CS2_1);

  x2_model #(
      .ADDRWID(`ADDRWID),
      .INIT(INIT),
      .INIT_FILE(INIT_FILE),
      .data_width_int(data_width_int),
      .data_depth_int(data_depth_int)
  ) x2_8K_model_inst (
      .Concat_En(Concat_En_SEL),

      .ram0_WIDTH_SELA(WIDTH_SELECT1_0),
      .ram0_WIDTH_SELB(WIDTH_SELECT2_0),
      .ram0_PLRD(PIPELINE_RD_0),

      .ram0_CEA(CLK1_0),
      .ram0_CEB(CLK2_0),
      .ram0_I(WD_0),
      .ram0_O(RD_0),
      .ram0_AA(RAM0_AA_SEL),
      .ram0_AB(RAM0_AB_SEL),
      .ram0_CSBA(RAM0_CS1_SEL),
      .ram0_CSBB(RAM0_CS2_SEL),
      .ram0_WENBA(RAM0_WENb1_SEL),

      .ram1_WIDTH_SELA(WIDTH_SELECT1_1),
      .ram1_WIDTH_SELB(WIDTH_SELECT2_1),
      .ram1_PLRD(PIPELINE_RD_1),

      .ram1_CEA(CLK1_1),
      .ram1_CEB(CLK2_1),
      .ram1_I(WD_1),
      .ram1_O(RD_1),
      .ram1_AA(RAM1_AA_SEL),
      .ram1_AB(RAM1_AB_SEL),
      .ram1_CSBA(RAM1_CS1_SEL),
      .ram1_CSBB(RAM1_CS2_SEL),
      .ram1_WENBA(RAM1_WENb1_SEL)
  );

  fifo_controller_model #(
      .MAX_PTR_WIDTH(`ADDRWID + 1)
  ) fifo_controller0_inst (
      .Push_Clk(CLK1_0),
      .Pop_Clk (CLK2_0),

      .Fifo_Push(PUSH_0),
      .Fifo_Push_Flush(CS1_0),
      .Fifo_Full(Almost_Full_0),
      .Fifo_Full_Usr(PUSH_FLAG_0),

      .Fifo_Pop(POP_0),
      .Fifo_Pop_Flush(CS2_0),
      .Fifo_Empty(Almost_Empty_0),
      .Fifo_Empty_Usr(POP_FLAG_0),

      .Write_Addr(Fifo0_Write_Addr),

      .Read_Addr(Fifo0_Read_Addr),

      .Fifo_Ram_Mode(Concat_En_SEL),
      .Fifo_Sync_Mode(SYNC_FIFO_0),
      .Fifo_Push_Width(WIDTH_SELECT1_0),
      .Fifo_Pop_Width(WIDTH_SELECT2_0),
      .Rst_n(fifo0_rstn)
  );

  fifo_controller_model #(
      .MAX_PTR_WIDTH(`ADDRWID + 1)
  ) fifo_controller1_inst (
      .Push_Clk(CLK1_1),
      .Pop_Clk (CLK2_1),

      .Fifo_Push(PUSH_1),
      .Fifo_Push_Flush(CS1_1),
      .Fifo_Full(Almost_Full_1),
      .Fifo_Full_Usr(PUSH_FLAG_1),

      .Fifo_Pop(POP_1),
      .Fifo_Pop_Flush(CS2_1),
      .Fifo_Empty(Almost_Empty_1),
      .Fifo_Empty_Usr(POP_FLAG_1),

      .Write_Addr(Fifo1_Write_Addr),

      .Read_Addr(Fifo1_Read_Addr),

      .Fifo_Ram_Mode(1'b0),
      .Fifo_Sync_Mode(SYNC_FIFO_1),
      .Fifo_Push_Width({1'b0, WIDTH_SELECT1_1[0]}),
      .Fifo_Pop_Width({1'b0, WIDTH_SELECT2_1[0]}),
      .Rst_n(fifo1_rstn)
  );

endmodule

module sw_mux (
    port_out,
    default_port,
    alt_port,
    switch
);

  output port_out;
  input default_port;
  input alt_port;
  input switch;

  assign port_out = switch ? alt_port : default_port;

endmodule


`define ADDRWID_8k2 11
`define DATAWID 18
`define WEWID 2

module ram8k_2x1_cell (
    CLK1_0,
    CLK2_0,
    CLK1S_0,
    CLK2S_0,
    WD_0,
    RD_0,
    A1_0,
    A2_0,
    CS1_0,
    CS2_0,
    WEN1_0,
    CLK1EN_0,
    CLK2EN_0,
    P1_0,
    P2_0,
    Almost_Full_0,
    Almost_Empty_0,
    PUSH_FLAG_0,
    POP_FLAG_0,

    FIFO_EN_0,
    SYNC_FIFO_0,
    PIPELINE_RD_0,
    WIDTH_SELECT1_0,
    WIDTH_SELECT2_0,
    DIR_0,
    ASYNC_FLUSH_0,
    ASYNC_FLUSH_S0,

    CLK1_1,
    CLK2_1,
    CLK1S_1,
    CLK2S_1,
    WD_1,
    RD_1,
    A1_1,
    A2_1,
    CS1_1,
    CS2_1,
    WEN1_1,
    CLK1EN_1,
    CLK2EN_1,
    P1_1,
    P2_1,
    Almost_Empty_1,
    Almost_Full_1,
    PUSH_FLAG_1,
    POP_FLAG_1,

    FIFO_EN_1,
    SYNC_FIFO_1,
    PIPELINE_RD_1,
    WIDTH_SELECT1_1,
    WIDTH_SELECT2_1,
    DIR_1,
    ASYNC_FLUSH_1,
    ASYNC_FLUSH_S1,

    CONCAT_EN_0,
    CONCAT_EN_1
);

  parameter [18431:0] INIT = 18432'bx;
  parameter INIT_FILE = "init.mem";
  parameter data_width_int = 16;
  parameter data_depth_int = 1024;

  input CLK1_0;
  input CLK2_0;
  input CLK1S_0;
  input CLK2S_0;
  input [`DATAWID-1:0] WD_0;
  output [`DATAWID-1:0] RD_0;
  input [`ADDRWID_8k2-1:0] A1_0;
  input [`ADDRWID_8k2-1:0] A2_0;
  input CS1_0;
  input CS2_0;
  input [`WEWID-1:0] WEN1_0;
  input CLK1EN_0;
  input CLK2EN_0;
  input P1_0;
  input P2_0;
  output Almost_Full_0;
  output Almost_Empty_0;
  output [3:0] PUSH_FLAG_0;
  output [3:0] POP_FLAG_0;
  input FIFO_EN_0;
  input SYNC_FIFO_0;
  input DIR_0;
  input ASYNC_FLUSH_0;
  input ASYNC_FLUSH_S0;
  input PIPELINE_RD_0;
  input [1:0] WIDTH_SELECT1_0;
  input [1:0] WIDTH_SELECT2_0;

  input CLK1_1;
  input CLK2_1;
  input CLK1S_1;
  input CLK2S_1;
  input [`DATAWID-1:0] WD_1;
  output [`DATAWID-1:0] RD_1;
  input [`ADDRWID_8k2-1:0] A1_1;
  input [`ADDRWID_8k2-1:0] A2_1;
  input CS1_1;
  input CS2_1;
  input [`WEWID-1:0] WEN1_1;
  input CLK1EN_1;
  input CLK2EN_1;
  input P1_1;
  input P2_1;
  output Almost_Full_1;
  output Almost_Empty_1;
  output [3:0] PUSH_FLAG_1;
  output [3:0] POP_FLAG_1;
  input FIFO_EN_1;
  input SYNC_FIFO_1;
  input DIR_1;
  input ASYNC_FLUSH_1;
  input ASYNC_FLUSH_S1;
  input PIPELINE_RD_1;
  input [1:0] WIDTH_SELECT1_1;
  input [1:0] WIDTH_SELECT2_1;

  input CONCAT_EN_0;
  input CONCAT_EN_1;

  //CODE here
  reg RAM0_domain_sw;
  reg RAM1_domain_sw;

  wire CLK1P_0, CLK1P_1, CLK2P_0, CLK2P_1, ASYNC_FLUSHP_1, ASYNC_FLUSHP_0;

  assign WidSel1_1 = WIDTH_SELECT1_0[1];
  assign WidSel2_1 = WIDTH_SELECT2_0[1];

  assign CLK1P_0 = CLK1S_0 ? ~CLK1_0 : CLK1_0;
  assign CLK1P_1 = CLK1S_1 ? ~CLK1_1 : CLK1_1;
  assign CLK2P_0 = CLK2S_0 ? ~CLK2_0 : CLK2_0;
  assign CLK2P_1 = CLK2S_1 ? ~CLK2_1 : CLK2_1;
  assign ASYNC_FLUSHP_0 = ASYNC_FLUSH_S0 ? ~ASYNC_FLUSH_0 : ASYNC_FLUSH_0;
  assign ASYNC_FLUSHP_1 = ASYNC_FLUSH_S1 ? ~ASYNC_FLUSH_1 : ASYNC_FLUSH_1;


  /* FIFO mode-only switching */
  always @(CONCAT_EN_0 or FIFO_EN_0 or FIFO_EN_1 or WidSel1_1 or WidSel2_1 or DIR_0 or DIR_1) begin
    if (CONCAT_EN_0)                                               //CONCAT enabled, only RAM0 ports are checked
		begin
      if (~FIFO_EN_0)                                              //RAM MODE (no switching)
			begin
        RAM0_domain_sw = 1'b0;  //Both Switches are on default during RAM mode
        RAM1_domain_sw = 1'b0;
      end
		else                                                               //FIFO Mode
			begin
        RAM0_domain_sw = DIR_0;  //Both Switches will get DIR_0 (primary port) during concat
        RAM1_domain_sw = DIR_0;
      end
    end
	else                                                                 //CONCAT disabled, RAM0 and RAM1 ports are be checked
		begin
      if (WidSel1_1 || WidSel2_1)        //AUTO-CONCAT FIFO/RAM Mode Horizontal Concatenation
				begin
        if (~FIFO_EN_0)                                          //RAM MODE (no switching)
					begin
          RAM0_domain_sw = 1'b0;  //Both Switches are on default during RAM mode
          RAM1_domain_sw = 1'b0;
        end
				else                                                           //FIFO Mode
					begin
          RAM0_domain_sw = DIR_0;  //Both Switches will get DIR_0 (primary port) during concat
          RAM1_domain_sw = DIR_0;
        end
      end
			else                                                             //FIFO/RAM Individual Mode
				begin
        if (~FIFO_EN_0)  //RAM0 Mode
          RAM0_domain_sw = 1'b0;
        else  //FIFO0 Mode
          RAM0_domain_sw = DIR_0;
        if (~FIFO_EN_1)  //RAM1 Mode
          RAM1_domain_sw = 1'b0;
        else  //FIFO1 Mode
          RAM1_domain_sw = DIR_1;
      end
    end
  end

  assign RAM0_Clk1_gated = CLK1EN_0 & CLK1P_0;
  assign RAM0_Clk2_gated = CLK2EN_0 & CLK2P_0;
  assign RAM1_Clk1_gated = CLK1EN_1 & CLK1P_1;
  assign RAM1_Clk2_gated = CLK2EN_1 & CLK2P_1;

  //PORT1 of RAMs is designated to PUSH circuitry, while PORT2 gets POP circuitry
  sw_mux RAM0_clk_sw_port1 (
      .port_out(RAM0_clk_port1),
      .default_port(RAM0_Clk1_gated),
      .alt_port(RAM0_Clk2_gated),
      .switch(RAM0_domain_sw)
  );
  sw_mux RAM0_P_sw_port1 (
      .port_out(RAM0_push_port1),
      .default_port(P1_0),
      .alt_port(P2_0),
      .switch(RAM0_domain_sw)
  );
  sw_mux RAM0_Flush_sw_port1 (
      .port_out(RAM0CS_Sync_Flush_port1),
      .default_port(CS1_0),
      .alt_port(CS2_0),
      .switch(RAM0_domain_sw)
  );
  sw_mux RAM0_WidSel0_port1 (
      .port_out(RAM0_Wid_Sel0_port1),
      .default_port(WIDTH_SELECT1_0[0]),
      .alt_port(WIDTH_SELECT2_0[0]),
      .switch(RAM0_domain_sw)
  );
  sw_mux RAM0_WidSel1_port1 (
      .port_out(RAM0_Wid_Sel1_port1),
      .default_port(WIDTH_SELECT1_0[1]),
      .alt_port(WIDTH_SELECT2_0[1]),
      .switch(RAM0_domain_sw)
  );

  sw_mux RAM0_clk_sw_port2 (
      .port_out(RAM0_clk_port2),
      .default_port(RAM0_Clk2_gated),
      .alt_port(RAM0_Clk1_gated),
      .switch(RAM0_domain_sw)
  );
  sw_mux RAM0_P_sw_port2 (
      .port_out(RAM0_pop_port2),
      .default_port(P2_0),
      .alt_port(P1_0),
      .switch(RAM0_domain_sw)
  );
  sw_mux RAM0_Flush_sw_port2 (
      .port_out(RAM0CS_Sync_Flush_port2),
      .default_port(CS2_0),
      .alt_port(CS1_0),
      .switch(RAM0_domain_sw)
  );
  sw_mux RAM0_WidSel0_port2 (
      .port_out(RAM0_Wid_Sel0_port2),
      .default_port(WIDTH_SELECT2_0[0]),
      .alt_port(WIDTH_SELECT1_0[0]),
      .switch(RAM0_domain_sw)
  );
  sw_mux RAM0_WidSel1_port2 (
      .port_out(RAM0_Wid_Sel1_port2),
      .default_port(WIDTH_SELECT2_0[1]),
      .alt_port(WIDTH_SELECT1_0[1]),
      .switch(RAM0_domain_sw)
  );

  sw_mux RAM1_clk_sw_port1 (
      .port_out(RAM1_clk_port1),
      .default_port(RAM1_Clk1_gated),
      .alt_port(RAM1_Clk2_gated),
      .switch(RAM1_domain_sw)
  );
  sw_mux RAM1_P_sw_port1 (
      .port_out(RAM1_push_port1),
      .default_port(P1_1),
      .alt_port(P2_1),
      .switch(RAM1_domain_sw)
  );
  sw_mux RAM1_Flush_sw_port1 (
      .port_out(RAM1CS_Sync_Flush_port1),
      .default_port(CS1_1),
      .alt_port(CS2_1),
      .switch(RAM1_domain_sw)
  );
  sw_mux RAM1_WidSel0_port1 (
      .port_out(RAM1_Wid_Sel0_port1),
      .default_port(WIDTH_SELECT1_1[0]),
      .alt_port(WIDTH_SELECT2_1[0]),
      .switch(RAM1_domain_sw)
  );
  sw_mux RAM1_WidSel1_port1 (
      .port_out(RAM1_Wid_Sel1_port1),
      .default_port(WIDTH_SELECT1_1[1]),
      .alt_port(WIDTH_SELECT2_1[1]),
      .switch(RAM1_domain_sw)
  );


  sw_mux RAM1_clk_sw_port2 (
      .port_out(RAM1_clk_port2),
      .default_port(RAM1_Clk2_gated),
      .alt_port(RAM1_Clk1_gated),
      .switch(RAM1_domain_sw)
  );
  sw_mux RAM1_P_sw_port2 (
      .port_out(RAM1_pop_port2),
      .default_port(P2_1),
      .alt_port(P1_1),
      .switch(RAM1_domain_sw)
  );
  sw_mux RAM1_Flush_sw_port2 (
      .port_out(RAM1CS_Sync_Flush_port2),
      .default_port(CS2_1),
      .alt_port(CS1_1),
      .switch(RAM1_domain_sw)
  );
  sw_mux RAM1_WidSel0_port2 (
      .port_out(RAM1_Wid_Sel0_port2),
      .default_port(WIDTH_SELECT2_1[0]),
      .alt_port(WIDTH_SELECT1_1[0]),
      .switch(RAM1_domain_sw)
  );
  sw_mux RAM1_WidSel1_port2 (
      .port_out(RAM1_Wid_Sel1_port2),
      .default_port(WIDTH_SELECT2_1[1]),
      .alt_port(WIDTH_SELECT1_1[1]),
      .switch(RAM1_domain_sw)
  );

  ram_block_8K #(
      .INIT(INIT),
      .INIT_FILE(INIT_FILE),
      .data_width_int(data_width_int),
      .data_depth_int(data_depth_int)
  ) ram_block_8K_inst (
      .CLK1_0(RAM0_clk_port1),
      .CLK2_0(RAM0_clk_port2),
      .WD_0(WD_0),
      .RD_0(RD_0),
      .A1_0(A1_0),
      .A2_0(A2_0),
      .CS1_0(RAM0CS_Sync_Flush_port1),
      .CS2_0(RAM0CS_Sync_Flush_port2),
      .WEN1_0(WEN1_0),
      .POP_0(RAM0_pop_port2),
      .Almost_Full_0(Almost_Full_0),
      .Almost_Empty_0(Almost_Empty_0),
      .PUSH_FLAG_0(PUSH_FLAG_0),
      .POP_FLAG_0(POP_FLAG_0),

      .FIFO_EN_0(FIFO_EN_0),
      .SYNC_FIFO_0(SYNC_FIFO_0),
      .PIPELINE_RD_0(PIPELINE_RD_0),
      .WIDTH_SELECT1_0({RAM0_Wid_Sel1_port1, RAM0_Wid_Sel0_port1}),
      .WIDTH_SELECT2_0({RAM0_Wid_Sel1_port2, RAM0_Wid_Sel0_port2}),

      .CLK1_1(RAM1_clk_port1),
      .CLK2_1(RAM1_clk_port2),
      .WD_1(WD_1),
      .RD_1(RD_1),
      .A1_1(A1_1),
      .A2_1(A2_1),
      .CS1_1(RAM1CS_Sync_Flush_port1),
      .CS2_1(RAM1CS_Sync_Flush_port2),
      .WEN1_1(WEN1_1),
      .POP_1(RAM1_pop_port2),
      .Almost_Empty_1(Almost_Empty_1),
      .Almost_Full_1(Almost_Full_1),
      .PUSH_FLAG_1(PUSH_FLAG_1),
      .POP_FLAG_1(POP_FLAG_1),

      .FIFO_EN_1(FIFO_EN_1),
      .SYNC_FIFO_1(SYNC_FIFO_1),
      .PIPELINE_RD_1(PIPELINE_RD_1),
      .WIDTH_SELECT1_1({RAM1_Wid_Sel1_port1, RAM1_Wid_Sel0_port1}),
      .WIDTH_SELECT2_1({RAM1_Wid_Sel1_port2, RAM1_Wid_Sel0_port2}),

      .CONCAT_EN_0(CONCAT_EN_0),
      .CONCAT_EN_1(CONCAT_EN_1),

      .PUSH_0(RAM0_push_port1),
      .PUSH_1(RAM1_push_port1),
      .aFlushN_0(~ASYNC_FLUSHP_0),
      .aFlushN_1(~ASYNC_FLUSHP_1)
  );

endmodule

module ram8k_2x1_cell_macro #(
    parameter [18431:0] INIT = 18432'bx,
    parameter INIT_FILE = "init.mem",
    parameter data_width_int = 16,
    parameter data_depth_int = 1024
) (
    input [10:0] A1_0,
    input [10:0] A1_1,
    input [10:0] A2_0,
    input [10:0] A2_1,
    (* clkbuf_sink *)
    input CLK1_0,
    (* clkbuf_sink *)
    input CLK1_1,
    (* clkbuf_sink *)
    input CLK2_0,
    (* clkbuf_sink *)
    input CLK2_1,
    output Almost_Empty_0,
    Almost_Empty_1,
    Almost_Full_0,
    Almost_Full_1,
    input ASYNC_FLUSH_0,
    ASYNC_FLUSH_1,
    ASYNC_FLUSH_S0,
    ASYNC_FLUSH_S1,
    CLK1EN_0,
    CLK1EN_1,
    CLK1S_0,
    CLK1S_1,
    CLK2EN_0,
    CLK2EN_1,
    CLK2S_0,
    CLK2S_1,
    CONCAT_EN_0,
    CONCAT_EN_1,
    CS1_0,
    CS1_1,
    CS2_0,
    CS2_1,
    DIR_0,
    DIR_1,
    FIFO_EN_0,
    FIFO_EN_1,
    P1_0,
    P1_1,
    P2_0,
    P2_1,
    PIPELINE_RD_0,
    PIPELINE_RD_1,
    output [3:0] POP_FLAG_0,
    output [3:0] POP_FLAG_1,
    output [3:0] PUSH_FLAG_0,
    output [3:0] PUSH_FLAG_1,
    output [17:0] RD_0,
    output [17:0] RD_1,
    input SYNC_FIFO_0,
    SYNC_FIFO_1,
    input [17:0] WD_0,
    input [17:0] WD_1,
    input [1:0] WEN1_0,
    input [1:0] WEN1_1,
    input [1:0] WIDTH_SELECT1_0,
    input [1:0] WIDTH_SELECT1_1,
    input [1:0] WIDTH_SELECT2_0,
    input [1:0] WIDTH_SELECT2_1,
    input SD,
    DS,
    LS,
    SD_RB1,
    LS_RB1,
    DS_RB1,
    RMEA,
    RMEB,
    TEST1A,
    TEST1B,
    input [3:0] RMA,
    input [3:0] RMB
);


  ram8k_2x1_cell #(
      .INIT(INIT),
      .INIT_FILE(INIT_FILE),
      .data_width_int(data_width_int),
      .data_depth_int(data_depth_int)
  ) I1 (
      .A1_0({A1_0[10:0]}),
      .A1_1({A1_1[10:0]}),
      .A2_0({A2_0[10:0]}),
      .A2_1({A2_1[10:0]}),
      .Almost_Empty_0(Almost_Empty_0),
      .Almost_Empty_1(Almost_Empty_1),
      .Almost_Full_0(Almost_Full_0),
      .Almost_Full_1(Almost_Full_1),
      .ASYNC_FLUSH_0(ASYNC_FLUSH_0),
      .ASYNC_FLUSH_1(ASYNC_FLUSH_1),
      .ASYNC_FLUSH_S0(ASYNC_FLUSH_S0),
      .ASYNC_FLUSH_S1(ASYNC_FLUSH_S1),
      .CLK1_0(CLK1_0),
      .CLK1_1(CLK1_1),
      .CLK1EN_0(CLK1EN_0),
      .CLK1EN_1(CLK1EN_1),
      .CLK1S_0(CLK1S_0),
      .CLK1S_1(CLK1S_1),
      .CLK2_0(CLK2_0),
      .CLK2_1(CLK2_1),
      .CLK2EN_0(CLK2EN_0),
      .CLK2EN_1(CLK2EN_1),
      .CLK2S_0(CLK2S_0),
      .CLK2S_1(CLK2S_1),
      .CONCAT_EN_0(CONCAT_EN_0),
      .CONCAT_EN_1(CONCAT_EN_1),
      .CS1_0(CS1_0),
      .CS1_1(CS1_1),
      .CS2_0(CS2_0),
      .CS2_1(CS2_1),
      .DIR_0(DIR_0),
      .DIR_1(DIR_1),
      .FIFO_EN_0(FIFO_EN_0),
      .FIFO_EN_1(FIFO_EN_1),
      .P1_0(P1_0),
      .P1_1(P1_1),
      .P2_0(P2_0),
      .P2_1(P2_1),
      .PIPELINE_RD_0(PIPELINE_RD_0),
      .PIPELINE_RD_1(PIPELINE_RD_1),
      .POP_FLAG_0({POP_FLAG_0[3:0]}),
      .POP_FLAG_1({POP_FLAG_1[3:0]}),
      .PUSH_FLAG_0({PUSH_FLAG_0[3:0]}),
      .PUSH_FLAG_1({PUSH_FLAG_1[3:0]}),
      .RD_0({RD_0[17:0]}),
      .RD_1({RD_1[17:0]}),
      .SYNC_FIFO_0(SYNC_FIFO_0),
      .SYNC_FIFO_1(SYNC_FIFO_1),
      .WD_0({WD_0[17:0]}),
      .WD_1({WD_1[17:0]}),
      .WEN1_0({WEN1_0[1:0]}),
      .WEN1_1({WEN1_1[1:0]}),
      .WIDTH_SELECT1_0({WIDTH_SELECT1_0[1:0]}),
      .WIDTH_SELECT1_1({WIDTH_SELECT1_1[1:0]}),
      .WIDTH_SELECT2_0({WIDTH_SELECT2_0[1:0]}),
      .WIDTH_SELECT2_1({WIDTH_SELECT2_1[1:0]})
  );

endmodule  /* ram8k_2x1_cell_macro */

module RAM_8K_BLK (
    WA,
    RA,
    WD,
    WClk,
    RClk,
    WClk_En,
    RClk_En,
    WEN,
    RD
);

  parameter addr_int 	= 9,
          data_depth_int = 512,
          data_width_int = 18,
          wr_enable_int 	= 2,
          reg_rd_int 	= 0;

  parameter [8191:0] INIT = 8192'bx;
  parameter INIT_FILE = "init.mem";

  input [addr_int-1:0] WA;
  input [addr_int-1:0] RA;
  input WClk, RClk;
  input WClk_En, RClk_En;
  input [wr_enable_int-1:0] WEN;
  input [data_width_int-1:0] WD;
  output [data_width_int-1:0] RD;

  wire VCC, GND;
  wire WClk0_Sel, RClk0_Sel;
  wire WClk1_Sel, RClk1_Sel;

  wire reg_rd0;
  wire reg_rd1;
  wire [10:0] addr_wr0, addr_rd0, addr_wr1, addr_rd1;

  wire [17:0] in_reg0;

  wire [ 2:0] wen_reg0;

  wire [15:0] out_reg0;

  wire [ 1:0] out_par0;

  wire [1:0] WS1_0, WS2_0;
  wire [1:0] WS_GND;

  wire LS, DS, SD, LS_RB1, DS_RB1, SD_RB1;

  wire WD0_SEL, RD0_SEL;
  wire WD1_SEL, RD1_SEL;

  assign VCC = 1'b1;
  assign GND = 1'b0;

  assign WD0_SEL = 1'b1;
  assign RD0_SEL = 1'b1;
  assign WD1_SEL = 1'b0;
  assign RD1_SEL = 1'b0;

  assign WClk0_Sel = 1'b0;
  assign RClk0_Sel = 1'b0;

  assign WClk1_Sel = 1'b0;
  assign RClk1_Sel = 1'b0;

  assign LS = 1'b0;
  assign DS = 1'b0;
  assign SD = 1'b0;
  assign LS_RB1 = 1'b0;
  assign DS_RB1 = 1'b0;
  assign SD_RB1 = 1'b0;

  assign reg_rd0 = reg_rd_int;
  assign WS_GND = 2'b00;

  assign reg_rd1 = 1'b0;

  assign wen_reg0[2:wr_enable_int] = 0;
  assign wen_reg0[wr_enable_int-1:0] = WEN;

  assign addr_wr1 = 11'b0000000000;
  assign addr_rd1 = 11'b0000000000;

  generate

    if (addr_int == 11) begin
      assign addr_wr0[10:0] = WA;
      assign addr_rd0[10:0] = RA;
    end else begin
      assign addr_wr0[10:addr_int]  = 0;
      assign addr_wr0[addr_int-1:0] = WA;
      assign addr_rd0[10:addr_int]  = 0;
      assign addr_rd0[addr_int-1:0] = RA;
    end

    if (data_width_int == 16) begin
      assign in_reg0[data_width_int-1:0] = WD[data_width_int-1:0];
    end else if (data_width_int > 8 && data_width_int < 16) begin
      assign in_reg0[15:data_width_int]  = 0;
      assign in_reg0[data_width_int-1:0] = WD[data_width_int-1:0];
    end else if (data_width_int <= 8) begin
      assign in_reg0[15:data_width_int]  = 0;
      assign in_reg0[data_width_int-1:0] = WD[data_width_int-1:0];
    end

    if (data_width_int <= 8) begin
      assign WS1_0 = 2'b00;
      assign WS2_0 = 2'b00;
    end else if (data_width_int > 8 && data_width_int <= 16) begin
      assign WS1_0 = 2'b01;
      assign WS2_0 = 2'b01;
    end else if (data_width_int > 16) begin
      assign WS1_0 = 2'b10;
      assign WS2_0 = 2'b10;
    end

  endgenerate

  ram8k_2x1_cell_macro #(
      `include "bram_init_8_16.vh"
      .INIT_FILE(INIT_FILE),
      .data_width_int(data_width_int),
      .data_depth_int(data_depth_int)
  ) U1 (
      .A1_0(addr_wr0),
      .A1_1(addr_wr1),
      .A2_0(addr_rd0),
      .A2_1(addr_rd1),
      .ASYNC_FLUSH_0(GND),  //chk
      .ASYNC_FLUSH_1(GND),  //chk
      .ASYNC_FLUSH_S0(GND),
      .ASYNC_FLUSH_S1(GND),
      .CLK1_0(WClk),
      .CLK1_1(GND),
      .CLK1S_0(WClk0_Sel),
      .CLK1S_1(WClk1_Sel),
      .CLK1EN_0(WClk_En),
      .CLK1EN_1(GND),
      .CLK2_0(RClk),
      .CLK2_1(GND),
      .CLK2S_0(RClk0_Sel),
      .CLK2S_1(RClk1_Sel),
      .CLK2EN_0(RClk_En),
      .CLK2EN_1(GND),
      .CONCAT_EN_0(GND),
      .CONCAT_EN_1(GND),
      .CS1_0(WD0_SEL),
      .CS1_1(WD1_SEL),
      .CS2_0(RD0_SEL),
      .CS2_1(RD1_SEL),
      .DIR_0(GND),
      .DIR_1(GND),
      .FIFO_EN_0(GND),
      .FIFO_EN_1(GND),
      .P1_0(GND),  //P1_0
      .P1_1(GND),  //P1_1
      .P2_0(GND),  //
      .P2_1(GND),  //
      .PIPELINE_RD_0(reg_rd0),
      .PIPELINE_RD_1(reg_rd1),
      .SYNC_FIFO_0(GND),
      .SYNC_FIFO_1(GND),
      .WD_1({18{GND}}),
      .WD_0({1'b0, in_reg0[15:8], 1'b0, in_reg0[7:0]}),
      .WIDTH_SELECT1_0(WS1_0),
      .WIDTH_SELECT1_1(WS_GND),
      .WIDTH_SELECT2_0(WS2_0),
      .WIDTH_SELECT2_1(WS_GND),
      .WEN1_0(wen_reg0[1:0]),
      .WEN1_1({2{GND}}),
      .Almost_Empty_0(),
      .Almost_Empty_1(),
      .Almost_Full_0(),
      .Almost_Full_1(),
      .POP_FLAG_0(),
      .POP_FLAG_1(),
      .PUSH_FLAG_0(),
      .PUSH_FLAG_1(),
      .RD_0({out_par0[1], out_reg0[15:8], out_par0[0], out_reg0[7:0]}),
      .RD_1(),
      .SD(SD),
      .SD_RB1(SD_RB1),
      .LS(LS),
      .LS_RB1(LS_RB1),
      .DS(DS),
      .DS_RB1(DS_RB1),
      .TEST1A(GND),
      .TEST1B(GND),
      .RMA(4'd0),
      .RMB(4'd0),
      .RMEA(GND),
      .RMEB(GND)
  );

  assign RD[data_width_int-1 : 0] = out_reg0[data_width_int-1 : 0];


endmodule


module RAM_16K_BLK (
    WA,
    RA,
    WD,
    WClk,
    RClk,
    WClk_En,
    RClk_En,
    WEN,
    RD
);

  parameter addr_int 	= 9,
          data_depth_int = 512,
	  		  data_width_int = 36,
          wr_enable_int 	= 4,
	  		  reg_rd_int 	= 0;

  parameter [16383:0] INIT = 16384'bx;
  parameter INIT_FILE = "init.mem";

  input [addr_int-1:0] WA;
  input [addr_int-1:0] RA;
  input WClk, RClk;
  input WClk_En, RClk_En;
  input [wr_enable_int-1:0] WEN;
  input [data_width_int-1:0] WD;
  output [data_width_int-1:0] RD;

  wire VCC, GND;

  wire WClk0_Sel, RClk0_Sel;
  wire WClk1_Sel, RClk1_Sel;

  wire reg_rd0;
  wire reg_rd1;
  wire [10:0] addr_wr0, addr_rd0, addr_wr1, addr_rd1;

  wire [31:0] in_reg0;

  wire [ 4:0] wen_reg0;

  wire [31:0] out_reg0;

  wire [ 3:0] out_par0;

  wire [1:0] WS1_0, WS2_0;
  wire [1:0] WS_GND;

  wire LS, DS, SD, LS_RB1, DS_RB1, SD_RB1;

  wire WD0_SEL, RD0_SEL;
  wire WD1_SEL, RD1_SEL;

  assign VCC = 1'b1;
  assign GND = 1'b0;

  assign WD0_SEL = 1'b1;
  assign RD0_SEL = 1'b1;
  assign WD1_SEL = 1'b1;
  assign RD1_SEL = 1'b1;

  assign WClk0_Sel = 1'b0;
  assign RClk0_Sel = 1'b0;

  assign WClk1_Sel = 1'b0;
  assign RClk1_Sel = 1'b0;

  assign LS = 1'b0;
  assign DS = 1'b0;
  assign SD = 1'b0;
  assign LS_RB1 = 1'b0;
  assign DS_RB1 = 1'b0;
  assign SD_RB1 = 1'b0;

  assign reg_rd0 = reg_rd_int;
  assign WS_GND = 2'b00;

  assign reg_rd1 = 1'b0;

  assign wen_reg0[4:wr_enable_int] = 0;
  assign wen_reg0[wr_enable_int-1:0] = WEN;

  assign addr_wr1 = 11'b0000000000;
  assign addr_rd1 = 11'b0000000000;

  generate

    if (addr_int == 11) begin
      assign addr_wr0[10:0] = WA;
      assign addr_rd0[10:0] = RA;
    end else begin
      assign addr_wr0[10:addr_int]  = 0;
      assign addr_wr0[addr_int-1:0] = WA;
      assign addr_rd0[10:addr_int]  = 0;
      assign addr_rd0[addr_int-1:0] = RA;
    end

    if (data_width_int == 32) begin
      assign in_reg0[data_width_int-1:0] = WD[data_width_int-1:0];
    end else if (data_width_int > 8 && data_width_int < 32) begin
      assign in_reg0[31:data_width_int]  = 0;
      assign in_reg0[data_width_int-1:0] = WD[data_width_int-1:0];
    end else if (data_width_int <= 8) begin
      assign in_reg0[31:data_width_int]  = 0;
      assign in_reg0[data_width_int-1:0] = WD[data_width_int-1:0];
    end

    if (data_width_int <= 8) begin
      assign WS1_0 = 2'b00;
      assign WS2_0 = 2'b00;
    end else if (data_width_int > 8 && data_width_int <= 16) begin
      assign WS1_0 = 2'b01;
      assign WS2_0 = 2'b01;
    end else if (data_width_int > 16) begin
      assign WS1_0 = 2'b10;
      assign WS2_0 = 2'b10;
    end

    if (data_width_int <= 16) begin

      ram8k_2x1_cell_macro #(
          `include "bram_init_8_16.vh"
          .INIT_FILE(INIT_FILE),
          .data_width_int(data_width_int),
          .data_depth_int(data_depth_int)
      ) U1 (
          .A1_0(addr_wr0),
          .A1_1(addr_wr1),
          .A2_0(addr_rd0),
          .A2_1(addr_rd1),
          .ASYNC_FLUSH_0(GND),
          .ASYNC_FLUSH_1(GND),
          .ASYNC_FLUSH_S0(GND),
          .ASYNC_FLUSH_S1(GND),
          .CLK1_0(WClk),
          .CLK1_1(WClk),
          .CLK1S_0(WClk0_Sel),
          .CLK1S_1(WClk0_Sel),
          .CLK1EN_0(WClk_En),
          .CLK1EN_1(WClk_En),
          .CLK2_0(RClk),
          .CLK2_1(RClk),
          .CLK2S_0(RClk0_Sel),
          .CLK2S_1(RClk0_Sel),
          .CLK2EN_0(RClk_En),
          .CLK2EN_1(RClk_En),
          .CONCAT_EN_0(VCC),
          .CONCAT_EN_1(GND),
          .CS1_0(WD0_SEL),
          .CS1_1(GND),
          .CS2_0(RD0_SEL),
          .CS2_1(GND),
          .DIR_0(GND),
          .DIR_1(GND),
          .FIFO_EN_0(GND),
          .FIFO_EN_1(GND),
          .P1_0(GND),
          .P1_1(GND),
          .P2_0(GND),
          .P2_1(GND),
          .PIPELINE_RD_0(reg_rd0),
          .PIPELINE_RD_1(GND),
          .SYNC_FIFO_0(GND),
          .SYNC_FIFO_1(GND),
          .WD_1({18{GND}}),
          .WD_0({1'b0, in_reg0[15:8], 1'b0, in_reg0[7:0]}),
          .WIDTH_SELECT1_0(WS1_0),
          .WIDTH_SELECT1_1(WS_GND),
          .WIDTH_SELECT2_0(WS2_0),
          .WIDTH_SELECT2_1(WS_GND),
          .WEN1_0(wen_reg0[1:0]),
          .WEN1_1(wen_reg0[3:2]),
          .Almost_Empty_0(),
          .Almost_Empty_1(),
          .Almost_Full_0(),
          .Almost_Full_1(),
          .POP_FLAG_0(),
          .POP_FLAG_1(),
          .PUSH_FLAG_0(),
          .PUSH_FLAG_1(),
          .RD_0({out_par0[1], out_reg0[15:8], out_par0[0], out_reg0[7:0]}),
          .RD_1(),
          .SD(SD),
          .SD_RB1(SD_RB1),
          .LS(LS),
          .LS_RB1(LS_RB1),
          .DS(DS),
          .DS_RB1(DS_RB1),
          .TEST1A(GND),
          .TEST1B(GND),
          .RMA(4'd0),
          .RMB(4'd0),
          .RMEA(GND),
          .RMEB(GND)
      );
    end else if (data_width_int > 16) begin

      ram8k_2x1_cell_macro #(
          `include "bram_init_32.vh"
          .INIT_FILE(INIT_FILE),
          .data_width_int(data_width_int),
          .data_depth_int(data_depth_int)
      ) U2 (
          .A1_0(addr_wr0),
          .A1_1(addr_wr1),
          .A2_0(addr_rd0),
          .A2_1(addr_rd1),
          .ASYNC_FLUSH_0(GND),
          .ASYNC_FLUSH_1(GND),
          .ASYNC_FLUSH_S0(GND),
          .ASYNC_FLUSH_S1(GND),
          .CLK1_0(WClk),
          .CLK1_1(WClk),
          .CLK1S_0(WClk0_Sel),
          .CLK1S_1(WClk0_Sel),
          .CLK1EN_0(WClk_En),
          .CLK1EN_1(WClk_En),
          .CLK2_0(RClk),
          .CLK2_1(RClk),
          .CLK2S_0(RClk0_Sel),
          .CLK2S_1(RClk0_Sel),
          .CLK2EN_0(RClk_En),
          .CLK2EN_1(RClk_En),
          .CONCAT_EN_0(VCC),
          .CONCAT_EN_1(GND),
          .CS1_0(WD0_SEL),
          .CS1_1(GND),
          .CS2_0(RD0_SEL),
          .CS2_1(GND),
          .DIR_0(GND),
          .DIR_1(GND),
          .FIFO_EN_0(GND),
          .FIFO_EN_1(GND),
          .P1_0(GND),
          .P1_1(GND),
          .P2_0(GND),
          .P2_1(GND),
          .PIPELINE_RD_0(reg_rd0),
          .PIPELINE_RD_1(GND),
          .SYNC_FIFO_0(GND),
          .SYNC_FIFO_1(GND),
          .WD_1({1'b0, in_reg0[31:24], 1'b0, in_reg0[23:16]}),
          .WD_0({1'b0, in_reg0[15:8], 1'b0, in_reg0[7:0]}),
          .WIDTH_SELECT1_0(WS1_0),
          .WIDTH_SELECT1_1(WS_GND),
          .WIDTH_SELECT2_0(WS2_0),
          .WIDTH_SELECT2_1(WS_GND),
          .WEN1_0(wen_reg0[1:0]),
          .WEN1_1(wen_reg0[3:2]),
          .Almost_Empty_0(),
          .Almost_Empty_1(),
          .Almost_Full_0(),
          .Almost_Full_1(),
          .POP_FLAG_0(),
          .POP_FLAG_1(),
          .PUSH_FLAG_0(),
          .PUSH_FLAG_1(),
          .RD_0({out_par0[1], out_reg0[15:8], out_par0[0], out_reg0[7:0]}),
          .RD_1({out_par0[3], out_reg0[31:24], out_par0[2], out_reg0[23:16]}),
          .SD(SD),
          .SD_RB1(SD_RB1),
          .LS(LS),
          .LS_RB1(LS_RB1),
          .DS(DS),
          .DS_RB1(DS_RB1),
          .TEST1A(GND),
          .TEST1B(GND),
          .RMA(4'd0),
          .RMB(4'd0),
          .RMEA(GND),
          .RMEB(GND)
      );
    end

  endgenerate

  assign RD[data_width_int-1 : 0] = out_reg0[data_width_int-1 : 0];

endmodule


module FIFO_8K_BLK (
    DIN,
    Fifo_Push_Flush,
    Fifo_Pop_Flush,
    PUSH,
    POP,
    Push_Clk,
    Pop_Clk,
    Push_Clk_En,
    Pop_Clk_En,
    Fifo_Dir,
    Async_Flush,
    Almost_Full,
    Almost_Empty,
    PUSH_FLAG,
    POP_FLAG,
    DOUT
);

  parameter data_depth_int = 512, data_width_int = 36, reg_rd_int = 0, sync_fifo_int = 0;

  input Fifo_Push_Flush, Fifo_Pop_Flush;
  input Push_Clk, Pop_Clk;
  input PUSH, POP;
  input [data_width_int-1:0] DIN;
  input Push_Clk_En, Pop_Clk_En, Fifo_Dir, Async_Flush;
  output [data_width_int-1:0] DOUT;
  output [3:0] PUSH_FLAG, POP_FLAG;
  output Almost_Full, Almost_Empty;

  wire LS, DS, SD, LS_RB1, DS_RB1, SD_RB1;
  wire VCC, GND;

  wire [10:0] addr_wr, addr_rd;
  wire clk1_sig0, clk2_sig0, clk1_sig_en0, clk2_sig_en0, fifo_clk1_flush_sig0, fifo_clk2_flush_sig0, p1_sig0, p2_sig0,clk1_sig_sel0,clk2_sig_sel0;
  wire reg_rd0, sync_fifo0;
  wire [15:0] in_reg0;
  wire [15:0] out_reg0;
  wire [ 1:0] WS1_0;
  wire [ 1:0] WS2_0;
  wire Push_Clk0_Sel, Pop_Clk0_Sel;
  wire Async_Flush_Sel0;

  wire [1:0] out_par0;

  assign LS = 1'b0;
  assign DS = 1'b0;
  assign SD = 1'b0;
  assign LS_RB1 = 1'b0;
  assign DS_RB1 = 1'b0;
  assign SD_RB1 = 1'b0;

  assign VCC = 1'b1;
  assign GND = 1'b0;

  assign Push_Clk0_Sel  	= 1'b0;
  assign Pop_Clk0_Sel   	= 1'b0;
  assign Async_Flush_Sel0 = 1'b0;

  assign reg_rd0 = reg_rd_int;
  assign sync_fifo0 = sync_fifo_int;

  assign addr_wr=11'b00000000000;
  assign addr_rd=11'b00000000000;

  assign clk1_sig0 = Fifo_Dir ? Pop_Clk : Push_Clk;
  assign clk2_sig0 = Fifo_Dir ? Push_Clk : Pop_Clk ;
  assign clk1_sig_en0 = Fifo_Dir ? Pop_Clk_En : Push_Clk_En;
  assign clk2_sig_en0 = Fifo_Dir ? Push_Clk_En : Pop_Clk_En ;
  assign clk1_sig_sel0 =  Push_Clk0_Sel;
  assign clk2_sig_sel0 =  Pop_Clk0_Sel ;
  assign fifo_clk1_flush_sig0 = Fifo_Dir ? Fifo_Pop_Flush : Fifo_Push_Flush;
  assign fifo_clk2_flush_sig0 = Fifo_Dir ? Fifo_Push_Flush : Fifo_Pop_Flush ;
  assign p1_sig0 = Fifo_Dir ? POP : PUSH;
  assign p2_sig0 = Fifo_Dir ? PUSH : POP ;

  generate

    if (data_width_int == 16) begin
      assign in_reg0[data_width_int-1:0] = DIN[data_width_int-1:0];
    end else if (data_width_int > 8 && data_width_int < 16) begin
      assign in_reg0[15:data_width_int]  = 0;
      assign in_reg0[data_width_int-1:0] = DIN[data_width_int-1:0];
    end else if (data_width_int <= 8) begin
      assign in_reg0[15:data_width_int]  = 0;
      assign in_reg0[data_width_int-1:0] = DIN[data_width_int-1:0];
    end

    if (data_width_int <= 8) begin
      assign WS1_0 = 2'b00;
      assign WS2_0 = 2'b00;
    end else if (data_width_int > 8 && data_width_int <= 16) begin
      assign WS1_0 = 2'b01;
      assign WS2_0 = 2'b01;
    end else if (data_width_int > 16) begin
      assign WS1_0 = 2'b10;
      assign WS2_0 = 2'b10;
    end

  endgenerate

  ram8k_2x1_cell_macro #(
      .data_width_int(data_width_int),
      .data_depth_int(data_depth_int)
  ) U1 (
      .A1_0(addr_wr),
      .A1_1(addr_wr),
      .A2_0(addr_rd),
      .A2_1(addr_rd),
      .ASYNC_FLUSH_0(Async_Flush),
      .ASYNC_FLUSH_1(GND),
      .ASYNC_FLUSH_S0(Async_Flush_Sel0),
      .ASYNC_FLUSH_S1(GND),
      .CLK1_0(clk1_sig0),
      .CLK1_1(GND),
      .CLK1EN_0(clk1_sig_en0),
      .CLK1EN_1(GND),
      .CLK2_0(clk2_sig0),
      .CLK2_1(GND),
      .CLK1S_0(clk1_sig_sel0),
      .CLK1S_1(GND),
      .CLK2S_0(clk2_sig_sel0),
      .CLK2S_1(GND),
      .CLK2EN_0(clk2_sig_en0),
      .CLK2EN_1(GND),
      .CONCAT_EN_0(GND),
      .CONCAT_EN_1(GND),
      .CS1_0(fifo_clk1_flush_sig0),
      .CS1_1(GND),
      .CS2_0(fifo_clk2_flush_sig0),
      .CS2_1(GND),
      .DIR_0(Fifo_Dir),
      .DIR_1(GND),
      .FIFO_EN_0(VCC),
      .FIFO_EN_1(GND),
      .P1_0(p1_sig0),
      .P1_1(GND),
      .P2_0(p2_sig0),
      .P2_1(GND),
      .PIPELINE_RD_0(reg_rd0),
      .PIPELINE_RD_1(GND),
      .SYNC_FIFO_0(sync_fifo0),
      .SYNC_FIFO_1(GND),
      .WD_1({18{GND}}),
      .WD_0({1'b0, in_reg0[15:8], 1'b0, in_reg0[7:0]}),
      .WIDTH_SELECT1_0(WS1_0),
      .WIDTH_SELECT1_1({GND, GND}),
      .WIDTH_SELECT2_0(WS2_0),
      .WIDTH_SELECT2_1({GND, GND}),
      .WEN1_0({GND, GND}),
      .WEN1_1({GND, GND}),
      .Almost_Empty_0(Almost_Empty),
      .Almost_Empty_1(),
      .Almost_Full_0(Almost_Full),
      .Almost_Full_1(),
      .POP_FLAG_0(POP_FLAG),
      .POP_FLAG_1(),
      .PUSH_FLAG_0(PUSH_FLAG),
      .PUSH_FLAG_1(),
      .RD_0({out_par0[1], out_reg0[15:8], out_par0[0], out_reg0[7:0]}),
      .RD_1(),
      .SD(SD),
      .SD_RB1(SD_RB1),
      .LS(LS),
      .LS_RB1(LS_RB1),
      .DS(DS),
      .DS_RB1(DS_RB1),
      .TEST1A(GND),
      .TEST1B(GND),
      .RMA(4'd0),
      .RMB(4'd0),
      .RMEA(GND),
      .RMEB(GND)
  );

  assign DOUT[data_width_int-1 : 0] = out_reg0[data_width_int-1 : 0];

endmodule


module FIFO_16K_BLK (
    DIN,
    Fifo_Push_Flush,
    Fifo_Pop_Flush,
    PUSH,
    POP,
    Push_Clk,
    Pop_Clk,
    Push_Clk_En,
    Pop_Clk_En,
    Fifo_Dir,
    Async_Flush,
    Almost_Full,
    Almost_Empty,
    PUSH_FLAG,
    POP_FLAG,
    DOUT
);

  parameter data_depth_int = 512, data_width_int = 36, reg_rd_int = 0, sync_fifo_int = 0;

  input Fifo_Push_Flush, Fifo_Pop_Flush;
  input Push_Clk, Pop_Clk;
  input PUSH, POP;
  input [data_width_int-1:0] DIN;
  input Push_Clk_En, Pop_Clk_En, Fifo_Dir, Async_Flush;
  output [data_width_int-1:0] DOUT;
  output [3:0] PUSH_FLAG, POP_FLAG;
  output Almost_Full, Almost_Empty;

  wire LS, DS, SD, LS_RB1, DS_RB1, SD_RB1;
  wire VCC, GND;

  wire [10:0] addr_wr, addr_rd;
  wire clk1_sig0, clk2_sig0, clk1_sig_en0, clk2_sig_en0, fifo_clk1_flush_sig0, fifo_clk2_flush_sig0, p1_sig0, p2_sig0,clk1_sig_sel0,clk2_sig_sel0;
  wire reg_rd0, sync_fifo0;
  wire [31:0] in_reg0;
  wire [31:0] out_reg0;
  wire [ 1:0] WS1_0;
  wire [ 1:0] WS2_0;
  wire Push_Clk0_Sel, Pop_Clk0_Sel;
  wire Async_Flush_Sel0;

  wire [3:0] out_par0;
  wire [1:0] out_par1;

  assign LS = 1'b0;
  assign DS = 1'b0;
  assign SD = 1'b0;
  assign LS_RB1 = 1'b0;
  assign DS_RB1 = 1'b0;
  assign SD_RB1 = 1'b0;

  assign VCC = 1'b1;
  assign GND = 1'b0;

  assign Push_Clk0_Sel  	= 1'b0;
  assign Pop_Clk0_Sel   	= 1'b0;
  assign Async_Flush_Sel0 = 1'b0;

  assign reg_rd0 = reg_rd_int;
  assign sync_fifo0 = sync_fifo_int;

  assign addr_wr=11'b00000000000;
  assign addr_rd=11'b00000000000;

  assign clk1_sig0 = Fifo_Dir ? Pop_Clk : Push_Clk;
  assign clk2_sig0 = Fifo_Dir ? Push_Clk : Pop_Clk ;
  assign clk1_sig_en0 = Fifo_Dir ? Pop_Clk_En : Push_Clk_En;
  assign clk2_sig_en0 = Fifo_Dir ? Push_Clk_En : Pop_Clk_En ;
  assign clk1_sig_sel0 =  Push_Clk0_Sel;
  assign clk2_sig_sel0 =  Pop_Clk0_Sel ;
  assign fifo_clk1_flush_sig0 = Fifo_Dir ? Fifo_Pop_Flush : Fifo_Push_Flush;
  assign fifo_clk2_flush_sig0 = Fifo_Dir ? Fifo_Push_Flush : Fifo_Pop_Flush ;
  assign p1_sig0 = Fifo_Dir ? POP : PUSH;
  assign p2_sig0 = Fifo_Dir ? PUSH : POP ;

  generate
    if (data_width_int == 32) begin
      assign in_reg0[data_width_int-1:0] = DIN[data_width_int-1:0];
    end else if (data_width_int > 8 && data_width_int < 32) begin
      assign in_reg0[31:data_width_int]  = 0;
      assign in_reg0[data_width_int-1:0] = DIN[data_width_int-1:0];
    end else if (data_width_int <= 8) begin
      assign in_reg0[31:data_width_int]  = 0;
      assign in_reg0[data_width_int-1:0] = DIN[data_width_int-1:0];
    end

    if (data_width_int <= 8) begin
      assign WS1_0 = 2'b00;
      assign WS2_0 = 2'b00;
    end else if (data_width_int > 8 && data_width_int <= 16) begin
      assign WS1_0 = 2'b01;
      assign WS2_0 = 2'b01;
    end else if (data_width_int > 16) begin
      assign WS1_0 = 2'b10;
      assign WS2_0 = 2'b10;
    end

    if (data_width_int <= 16) begin

      ram8k_2x1_cell_macro #(
          .data_width_int(data_width_int),
          .data_depth_int(data_depth_int)
      ) U1 (
          .A1_0(addr_wr),
          .A1_1(addr_wr),
          .A2_0(addr_rd),
          .A2_1(addr_rd),
          .ASYNC_FLUSH_0(Async_Flush),
          .ASYNC_FLUSH_1(GND),
          .ASYNC_FLUSH_S0(Async_Flush_Sel0),
          .ASYNC_FLUSH_S1(Async_Flush_Sel0),
          .CLK1_0(clk1_sig0),
          .CLK1_1(clk1_sig0),
          .CLK1EN_0(clk1_sig_en0),
          .CLK1EN_1(clk1_sig_en0),
          .CLK2_0(clk2_sig0),
          .CLK2_1(clk2_sig0),
          .CLK1S_0(clk1_sig_sel0),
          .CLK1S_1(clk1_sig_sel0),
          .CLK2S_0(clk2_sig_sel0),
          .CLK2S_1(clk2_sig_sel0),
          .CLK2EN_0(clk2_sig_en0),
          .CLK2EN_1(clk2_sig_en0),
          .CONCAT_EN_0(VCC),
          .CONCAT_EN_1(GND),
          .CS1_0(fifo_clk1_flush_sig0),
          .CS1_1(GND),
          .CS2_0(fifo_clk2_flush_sig0),
          .CS2_1(GND),
          .DIR_0(Fifo_Dir),
          .DIR_1(GND),
          .FIFO_EN_0(VCC),
          .FIFO_EN_1(GND),
          .P1_0(p1_sig0),
          .P1_1(GND),
          .P2_0(p2_sig0),
          .P2_1(GND),
          .PIPELINE_RD_0(reg_rd0),
          .PIPELINE_RD_1(GND),
          .SYNC_FIFO_0(sync_fifo0),
          .SYNC_FIFO_1(GND),
          .WD_1({18{GND}}),
          .WD_0({1'b0, in_reg0[15:8], 1'b0, in_reg0[7:0]}),
          .WIDTH_SELECT1_0(WS1_0),
          .WIDTH_SELECT1_1({GND, GND}),
          .WIDTH_SELECT2_0(WS2_0),
          .WIDTH_SELECT2_1({GND, GND}),
          .WEN1_0({GND, GND}),
          .WEN1_1({GND, GND}),
          .Almost_Empty_0(Almost_Empty),
          .Almost_Empty_1(),
          .Almost_Full_0(Almost_Full),
          .Almost_Full_1(),
          .POP_FLAG_0(POP_FLAG),
          .POP_FLAG_1(),
          .PUSH_FLAG_0(PUSH_FLAG),
          .PUSH_FLAG_1(),
          .RD_0({out_par0[1], out_reg0[15:8], out_par0[0], out_reg0[7:0]}),
          .RD_1(),
          .SD(SD),
          .SD_RB1(SD_RB1),
          .LS(LS),
          .LS_RB1(LS_RB1),
          .DS(DS),
          .DS_RB1(DS_RB1),
          .TEST1A(GND),
          .TEST1B(GND),
          .RMA(4'd0),
          .RMB(4'd0),
          .RMEA(GND),
          .RMEB(GND)
      );

    end else if (data_width_int > 16) begin

      ram8k_2x1_cell_macro #(
          .data_width_int(data_width_int),
          .data_depth_int(data_depth_int)
      ) U2 (
          .A1_0(addr_wr),
          .A1_1(addr_wr),
          .A2_0(addr_rd),
          .A2_1(addr_rd),
          .ASYNC_FLUSH_0(Async_Flush),
          .ASYNC_FLUSH_1(GND),
          .ASYNC_FLUSH_S0(Async_Flush_Sel0),
          .ASYNC_FLUSH_S1(Async_Flush_Sel0),
          .CLK1_0(clk1_sig0),
          .CLK1_1(clk1_sig0),
          .CLK1EN_0(clk1_sig_en0),
          .CLK1EN_1(clk1_sig_en0),
          .CLK2_0(clk2_sig0),
          .CLK2_1(clk2_sig0),
          .CLK1S_0(clk1_sig_sel0),
          .CLK1S_1(clk1_sig_sel0),
          .CLK2S_0(clk2_sig_sel0),
          .CLK2S_1(clk2_sig_sel0),
          .CLK2EN_0(clk2_sig_en0),
          .CLK2EN_1(clk2_sig_en0),
          .CONCAT_EN_0(VCC),
          .CONCAT_EN_1(GND),
          .CS1_0(fifo_clk1_flush_sig0),
          .CS1_1(GND),
          .CS2_0(fifo_clk2_flush_sig0),
          .CS2_1(GND),
          .DIR_0(Fifo_Dir),
          .DIR_1(GND),
          .FIFO_EN_0(VCC),
          .FIFO_EN_1(GND),
          .P1_0(p1_sig0),
          .P1_1(GND),
          .P2_0(p2_sig0),
          .P2_1(GND),
          .PIPELINE_RD_0(reg_rd0),
          .PIPELINE_RD_1(GND),
          .SYNC_FIFO_0(sync_fifo0),
          .SYNC_FIFO_1(GND),
          .WD_1({1'b0, in_reg0[31:24], 1'b0, in_reg0[23:16]}),
          .WD_0({1'b0, in_reg0[15:8], 1'b0, in_reg0[7:0]}),
          .WIDTH_SELECT1_0(WS1_0),
          .WIDTH_SELECT1_1({GND, GND}),
          .WIDTH_SELECT2_0(WS2_0),
          .WIDTH_SELECT2_1({GND, GND}),
          .WEN1_0({GND, GND}),
          .WEN1_1({GND, GND}),
          .Almost_Empty_0(Almost_Empty),
          .Almost_Empty_1(),
          .Almost_Full_0(Almost_Full),
          .Almost_Full_1(),
          .POP_FLAG_0(POP_FLAG),
          .POP_FLAG_1(),
          .PUSH_FLAG_0(PUSH_FLAG),
          .PUSH_FLAG_1(),
          .RD_0({out_par0[1], out_reg0[15:8], out_par0[0], out_reg0[7:0]}),
          .RD_1({out_par0[3], out_reg0[31:24], out_par0[2], out_reg0[23:16]}),
          .SD(SD),
          .SD_RB1(SD_RB1),
          .LS(LS),
          .LS_RB1(LS_RB1),
          .DS(DS),
          .DS_RB1(DS_RB1),
          .TEST1A(GND),
          .TEST1B(GND),
          .RMA(4'd0),
          .RMB(4'd0),
          .RMEA(GND),
          .RMEB(GND)
      );
    end

  endgenerate

  assign DOUT[data_width_int-1 : 0] = out_reg0[data_width_int-1 : 0];

endmodule

