module mac_unit(a, b, out);
  parameter DATA_WIDTH = 16;
  input [DATA_WIDTH - 1 : 0] a, b;
  output [2*DATA_WIDTH - 1 : 0] out;

  assign out = a * b + out;
endmodule

