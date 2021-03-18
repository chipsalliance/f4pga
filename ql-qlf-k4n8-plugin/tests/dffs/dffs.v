module my_dff (
    input d,
    clk,
    output reg q
);
  initial q <= 1'b0;
  always @(posedge clk) q <= d;
endmodule

module my_dffr_p (
    input d,
    clk,
    clr,
    output reg q
);
  initial q <= 1'b0;
  always @(posedge clk or posedge clr)
    if (clr) q <= 1'b0;
    else q <= d;
endmodule

module my_dffr_n (
    input d,
    clk,
    clr,
    output reg q
);
  initial q <= 1'b0;
  always @(posedge clk or negedge clr)
    if (!clr) q <= 1'b0;
    else q <= d;
endmodule

module my_dffs_p (
    input d,
    clk,
    pre,
    output reg q
);
  initial q <= 1'b0;
  always @(posedge clk or posedge pre)
    if (pre) q <= 1'b1;
    else q <= d;
endmodule

module my_dffs_n (
    input d,
    clk,
    pre,
    output reg q
);
  initial q <= 1'b0;
  always @(posedge clk or negedge pre)
    if (!pre) q <= 1'b1;
    else q <= d;
endmodule

