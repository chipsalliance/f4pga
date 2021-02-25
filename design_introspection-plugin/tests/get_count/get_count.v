module my_gate (
    input  wire A,
    output wire Y
);

    assign Y = ~A;
endmodule

module top (
    input  wire [7:0] di,
    output wire [7:0] do
);

    my_gate c0 (.A(di[0]), .Y(do[0]));
    \$_BUF_ c1 (.A(di[1]), .Y(do[1]));
    \$_BUF_ c2 (.A(di[2]), .Y(do[2]));
    \$_BUF_ c3 (.A(di[3]), .Y(do[3]));
    \$_BUF_ c4 (.A(di[4]), .Y(do[4]));
    \$_NOT_ c5 (.A(di[5]), .Y(do[5]));
    \$_NOT_ c6 (.A(di[6]), .Y(do[6]));
    \$_NOT_ c7 (.A(di[7]), .Y(do[7]));

endmodule
