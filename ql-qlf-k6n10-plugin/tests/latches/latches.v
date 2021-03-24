module latchp (
    input d,
    clk,
    en,
    output reg q
);
  always @* if (en) q <= d;
endmodule

