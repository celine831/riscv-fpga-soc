module regsfile (
    input  wire        sys_clk,
    input  wire        sys_rst_n,

    //写端口
    input  wire        wen,
    input  wire [4:0]  waddr,
    input  wire [31:0] wdata,

    //2个读端口
    input  wire [4:0]  raddr1,
    input  wire [4:0]  raddr2,
    

    output wire [31:0] rdata1,
    output wire [31:0] rdata2
);

reg [31:0] regs [0:31];

integer i;

// 异步复位，时钟上升沿写入
always @(posedge sys_clk or negedge sys_rst_n) 
    if (sys_rst_n == 0) 
            begin
                for (i = 0; i < 32; i = i + 1)
                    regs[i] <= 32'd0;
            end
    else if (wen==1'b1 && (waddr != 5'd0)) 
                regs[waddr] <= wdata;

// 组合读取，x0 始终读出 0
assign rdata1 = (raddr1 == 5'd0) ? 32'd0 : regs[raddr1];
assign rdata2 = (raddr2 == 5'd0) ? 32'd0 : regs[raddr2];

endmodule