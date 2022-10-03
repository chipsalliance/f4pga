module top (
    input clk,
    input clk2,
    input [1:0] in,
    output [5:0] out
);

  reg [1:0] cnt = 0;
  wire clk_int_1, clk_int_2;
  IBUF ibuf_proxy (
      .I(clk),
      .O(ibuf_proxy_out)
  );
  IBUF ibuf_inst (
      .I(ibuf_proxy_out),
      .O(ibuf_out)
  );
  assign clk_int_1 = ibuf_out;
  assign clk_int_2 = clk_int_1;

  always @(posedge clk_int_2) begin
    cnt <= cnt + 1;
  end

  middle middle_inst_1 (
      .clk(ibuf_out),
      .out(out[2])
  );
  middle middle_inst_2 (
      .clk(clk_int_1),
      .out(out[3])
  );
  middle middle_inst_3 (
      .clk(clk_int_2),
      .out(out[4])
  );
  middle middle_inst_4 (
      .clk(clk2),
      .out(out[5])
  );

  assign out[1:0] = {cnt[0], in[0]};
endmodule

module middle (
    input  clk,
    output out
);

  reg [1:0] cnt = 0;
  wire clk_int;
  assign clk_int = clk;
  always @(posedge clk_int) begin
    cnt <= cnt + 1;
  end

  assign out = cnt[0];
endmodule
