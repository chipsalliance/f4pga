module mult_ena (
    input  wire        CLK,
    input  wire        ENA,
    input  wire [ 8:0] A,
    input  wire [ 8:0] B,
    output wire [17:0] Z
);

    reg [8:0] ra;
    always @(posedge CLK)
        if (ENA) ra <= A;

    MULT9X9 # (
        .REGINPUTA("BYPASS"),
        .REGINPUTB("BYPASS"),
        .REGOUTPUT("BYPASS")
    ) mult (
        .A (ra),
        .B (B),
        .Z (Z)
    );

endmodule

module mult_arst (
    input  wire        CLK,
    input  wire        RST,
    input  wire [ 8:0] A,
    input  wire [ 8:0] B,
    output wire [17:0] Z
);

    reg [8:0] ra;
    always @(posedge CLK or posedge RST)
        if (RST) ra <= 0;
        else     ra <= A;

    MULT9X9 # (
        .REGINPUTA("BYPASS"),
        .REGINPUTB("BYPASS"),
        .REGOUTPUT("BYPASS")
    ) mult (
        .A (ra),
        .B (B),
        .Z (Z)
    );

endmodule

module mult_arst_ena (
    input  wire        CLK,
    input  wire        RST,
    input  wire        ENA,
    input  wire [ 8:0] A,
    input  wire [ 8:0] B,
    output wire [17:0] Z
);

    reg [8:0] ra;
    always @(posedge CLK or posedge RST)
        if (RST)      ra <= 0;
        else if (ENA) ra <= A;

    MULT9X9 # (
        .REGINPUTA("BYPASS"),
        .REGINPUTB("BYPASS"),
        .REGOUTPUT("BYPASS")
    ) mult (
        .A (ra),
        .B (B),
        .Z (Z)
    );

endmodule

module mult_srst (
    input  wire        CLK,
    input  wire        RST,
    input  wire [ 8:0] A,
    input  wire [ 8:0] B,
    output wire [17:0] Z
);

    reg [8:0] ra;
    always @(posedge CLK)
        if (RST) ra <= 0;
        else     ra <= A;

    MULT9X9 # (
        .REGINPUTA("BYPASS"),
        .REGINPUTB("BYPASS"),
        .REGOUTPUT("BYPASS")
    ) mult (
        .A (ra),
        .B (B),
        .Z (Z)
    );

endmodule

module mult_srst_ena (
    input  wire        CLK,
    input  wire        RST,
    input  wire        ENA,
    input  wire [ 8:0] A,
    input  wire [ 8:0] B,
    output wire [17:0] Z
);

    reg [8:0] ra;
    always @(posedge CLK)
        if (RST)      ra <= 0;
        else if (ENA) ra <= A;

    MULT9X9 # (
        .REGINPUTA("BYPASS"),
        .REGINPUTB("BYPASS"),
        .REGOUTPUT("BYPASS")
    ) mult (
        .A (ra),
        .B (B),
        .Z (Z)
    );

endmodule

