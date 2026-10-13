module timer
(
    input  wire        sys_clk,
    input  wire        sys_rst_n,
    // 写总线只接上一拍锁存的 CPU 命令；读总线保持 CPU 的组合地址。
    input  wire        sel,
    input  wire        wen,
    input  wire        ren,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    input  wire        read_sel,
    input  wire [31:0] read_addr,
    output reg  [31:0] rdata,
    output wire        irq
);

localparam [31:0] CTRL_ADDR   = 32'h1000_1000;
localparam [31:0] LOAD_ADDR   = 32'h1000_1004;
localparam [31:0] VALUE_ADDR  = 32'h1000_1008;
localparam [31:0] STATUS_ADDR = 32'h1000_100C;

reg        enable;
reg        periodic;
reg [31:0] load_value;
reg [31:0] count_value;
reg        expired;
assign irq = expired;

wire write_ctrl;
wire write_status;
assign write_ctrl = sel && wen && (addr == CTRL_ADDR);
assign write_status = sel && wen && (addr == STATUS_ADDR);

// 复位后关闭；CTRL[0]启动，CTRL[1]选择循环计数。
// 停止->启动时从LOAD装载；写LOAD只影响下一次启动/自动重装。
// 倒数到1时置位sticky STATUS[0]，单次模式停止，循环模式重装。
// STATUS[0]写1清零，清零与到期同沿时清零优先。
always @(posedge sys_clk or negedge sys_rst_n)
    if (sys_rst_n == 1'b0)
    begin
        enable      <= 1'b0;
        periodic    <= 1'b0;
        load_value  <= 32'd0;
        count_value <= 32'd0;
        expired     <= 1'b0;
    end
    else
    begin
        if (sel && wen && (addr == LOAD_ADDR))
            load_value <= wdata;

        if (write_ctrl)
        begin
            enable   <= wdata[0] && (load_value != 32'd0);
            periodic <= wdata[1];
            if (wdata[0] && !enable)
                count_value <= load_value;
            else if (!wdata[0])
                count_value <= 32'd0;
        end
        else if (enable && (count_value != 32'd0))
        begin
            if (count_value == 32'd1)
            begin
                if (periodic && (load_value != 32'd0))
                    count_value <= load_value;
                else
                begin
                    count_value <= 32'd0;
                    enable <= 1'b0;
                end
                if (!write_status || !wdata[0])
                    expired <= 1'b1;
            end
            else
                count_value <= count_value - 32'd1;
        end

        if (write_status && wdata[0])
            expired <= 1'b0;
    end

// 同步读，与RAM/GPIO同样在读请求的上升沿后更新。
always @(posedge sys_clk or negedge sys_rst_n)
    if (sys_rst_n == 1'b0)
        rdata <= 32'd0;
    else if (read_sel && ren)
        case (read_addr)
            CTRL_ADDR:   rdata <= {30'd0, periodic, enable};
            LOAD_ADDR:   rdata <= load_value;
            VALUE_ADDR:  rdata <= count_value;
            STATUS_ADDR: rdata <= {31'd0, expired};
            default:     rdata <= 32'd0;
        endcase
    else
        rdata <= 32'd0;

endmodule
