module pc_reg
(
    input  wire        sys_clk,
    input  wire        sys_rst_n,
    input  wire [31:0] pc_next,
    output reg  [31:0] pc
);

always @(posedge sys_clk or negedge sys_rst_n) begin
    if (sys_rst_n==1'b0)
        pc <= 32'h00000000;
    else
        pc <= pc_next;
end

endmodule