module uart_tx
#(parameter integer CLKS_PER_BIT = 434)
(
    input  wire        sys_clk,
    input  wire        sys_rst_n,
    input  wire        sel,
    input  wire        wen,
    input  wire        ren,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    input  wire        read_sel,
    input  wire [31:0] read_addr,
    output reg  [31:0] rdata,
    output reg         tx
);

localparam [31:0] TXDATA_ADDR = 32'h1000_2000;
localparam [31:0] STATUS_ADDR = 32'h1000_2004;

reg        busy;
reg [9:0]  frame;
reg [3:0]  bits_left;
reg [15:0] baud_count;

// 8N1: 空闲高电平、起始0、8个数据位低位先发、停止1。
// busy期间写TXDATA不覆盖正在发送的字节。
always @(posedge sys_clk or negedge sys_rst_n)
    if (sys_rst_n == 1'b0)
    begin
        busy       <= 1'b0;
        frame      <= 10'h3FF;
        bits_left  <= 4'd0;
        baud_count <= 16'd0;
        tx         <= 1'b1;
    end
    else if (sel && wen && (addr == TXDATA_ADDR) && !busy)
    begin
        frame      <= {1'b1,wdata[7:0],1'b0};
        bits_left  <= 4'd10;
        baud_count <= CLKS_PER_BIT - 1;
        busy       <= 1'b1;
        tx         <= 1'b0;
    end
    else if (busy)
        if (baud_count != 16'd0)
            baud_count <= baud_count - 16'd1;
        else if (bits_left == 4'd1)
        begin
            busy      <= 1'b0;
            bits_left <= 4'd0;
            tx        <= 1'b1;
        end
        else
        begin
            tx         <= frame[1];
            frame      <= {1'b1,frame[9:1]};
            bits_left  <= bits_left - 4'd1;
            baud_count <= CLKS_PER_BIT - 1;
        end

// 同步读。STATUS[0]=busy，TXDATA只写。
always @(posedge sys_clk or negedge sys_rst_n)
    if (sys_rst_n == 1'b0)
        rdata <= 32'd0;
    else if (read_sel && ren)
        case (read_addr)
            STATUS_ADDR: rdata <= {31'd0,busy};
            default:     rdata <= 32'd0;
        endcase
    else
        rdata <= 32'd0;

endmodule
