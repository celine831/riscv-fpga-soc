module data_ram
#(
    // 2^8 = 256 个32位存储单元，共 1024 Byte（1 KiB）
    parameter ADDR_WIDTH = 8
)
(
    input  wire        sys_clk,
    input  wire        sys_rst_n,

    input  wire        wen,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,

    // 同步读：地址在上升沿被采样，数据在该上升沿后输出
    output wire [31:0] rdata
);

localparam MEM_DEPTH = (1 << ADDR_WIDTH);

// 同步读写写法便于Quartus将这256×32 bit存储器推断为M9K。
(* ramstyle = "M9K" *) reg [31:0] mem [0:MEM_DEPTH-1];

// CPU给出字节地址；每个字占4 Byte，所以用addr[9:2]选择字。
wire [ADDR_WIDTH-1:0] word_addr;
assign word_addr = addr[ADDR_WIDTH+1:2];

// 只允许访问0～1023，且地址必须按4 Byte对齐。
wire addr_valid;
assign addr_valid = (addr[1:0] == 2'b00) &&
                    (addr[31:ADDR_WIDTH+2] == 0);

reg [31:0] rdata_reg;
reg        read_valid_reg;

// RAM主体不能使用复位清空循环，否则通常会被实现为大量逻辑单元。
always @(posedge sys_clk)
begin
    if ((wen == 1'b1) && (addr_valid == 1'b1))
        mem[word_addr] <= wdata;

    // 同一地址同时读写时，读出写入前的旧值。
    rdata_reg <= mem[word_addr];
end

// 合法标志与RAM读数据保持相同的一拍延迟。
always @(posedge sys_clk or negedge sys_rst_n)
begin
    if (sys_rst_n == 1'b0)
        read_valid_reg <= 1'b0;
    else
        read_valid_reg <= addr_valid;
end

// 复位期间或上一拍地址非法时，对CPU输出0。
assign rdata = ((sys_rst_n == 1'b1) && (read_valid_reg == 1'b1))
             ? rdata_reg
             : 32'd0;

endmodule
