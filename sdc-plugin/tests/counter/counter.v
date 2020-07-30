module top(input clk,
	input [1:0] in,
	output [4:0] out);

reg [1:0] cnt = 0;
wire clk_int_1, clk_int_2;

assign clk_int_1 = clk;
assign clk_int_2 = clk_int_1;

always @(posedge clk_int) begin
	cnt <= cnt + 1;
end

middle middle_inst_1(.clk(clk_int_1), .out(out[2]));
middle middle_inst_2(.clk(clk_int_1), .out(out[3]));
middle middle_inst_3(.clk(clk_int_2), .out(out[4]));

assign out[1:0] = {cnt[0], in[0]};
endmodule

module middle(input clk,
	output out);

reg [1:0] cnt = 0;
wire clk_int;
assign clk_int = clk;
always @(posedge clk_int) begin
	cnt <= cnt + 1;
end

assign out = cnt[0];
endmodule
/*
module dut();
reg clk;
wire [1:0] out;

top dut(.clk(clk), .in(2'b11), .out(out));
initial begin
	$dumpfile("test.vcd");
	$dumpvars(0,dut);
	clk = 0;
end

always
begin
	clk = #5 !clk;
end
endmodule
*/
