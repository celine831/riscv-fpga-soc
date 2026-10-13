module uart_rx
#(parameter integer CLKS_PER_BIT = 434)
(
    input  wire        sys_clk,
    input  wire        sys_rst_n,
    input  wire        rx_pin,
    input  wire        sel,
    input  wire        wen,
    input  wire        ren,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    output reg  [31:0] rdata
);

localparam [31:0] RXDATA_ADDR = 32'h1000_3000;
localparam [31:0] STATUS_ADDR = 32'h1000_3004;
localparam [1:0] IDLE=2'd0, START=2'd1, DATA=2'd2, STOP=2'd3;

reg rx_meta,rx_sync;
reg [1:0] state;
reg [15:0] baud_count;
reg [2:0] bit_index;
reg [7:0] shift_data,rx_data;
reg valid;

wire clear_valid;
assign clear_valid = sel && wen && addr == STATUS_ADDR && wdata[0];

// 异步串口输入先经两级寄存器同步，再在每位中间采样。
always @(posedge sys_clk or negedge sys_rst_n)
    if (sys_rst_n == 1'b0)
    begin
        rx_meta <= 1'b1;
        rx_sync <= 1'b1;
    end
    else
    begin
        rx_meta <= rx_pin;
        rx_sync <= rx_meta;
    end

// 8N1接收。valid置位后保持，CPU写STATUS[0]=1确认已读。
// 若CPU尚未确认，则保持旧字节，忽略随后收到的字节。
always @(posedge sys_clk or negedge sys_rst_n)
    if (sys_rst_n == 1'b0)
    begin
        state      <= IDLE;
        baud_count <= 16'd0;
        bit_index  <= 3'd0;
        shift_data <= 8'd0;
        rx_data    <= 8'd0;
        valid      <= 1'b0;
    end
    else
    begin
        case (state)
            IDLE:
                if (!rx_sync)
                begin
                    state <= START;
                    baud_count <= (CLKS_PER_BIT / 2) - 1;
                end
            START:
                if (baud_count != 16'd0)
                    baud_count <= baud_count - 16'd1;
                else if (!rx_sync)
                begin
                    state <= DATA;
                    baud_count <= CLKS_PER_BIT - 1;
                    bit_index <= 3'd0;
                end
                else
                    state <= IDLE; // 假起始位
            DATA:
                if (baud_count != 16'd0)
                    baud_count <= baud_count - 16'd1;
                else
                begin
                    shift_data[bit_index] <= rx_sync;
                    baud_count <= CLKS_PER_BIT - 1;
                    if (bit_index == 3'd7)
                        state <= STOP;
                    else
                        bit_index <= bit_index + 3'd1;
                end
            STOP:
                if (baud_count != 16'd0)
                    baud_count <= baud_count - 16'd1;
                else
                begin
                    state <= IDLE;
                    if (rx_sync && !valid)
                    begin
                        rx_data <= shift_data;
                        valid <= 1'b1;
                    end
                end
            default: state <= IDLE;
        endcase
        if (clear_valid)
            valid <= 1'b0;
    end

// 同步MMIO读：DATA只读；STATUS[0]为valid，写1清除。
always @(posedge sys_clk or negedge sys_rst_n)
    if (sys_rst_n == 1'b0)
        rdata <= 32'd0;
    else if (sel && ren)
        case (addr)
            RXDATA_ADDR: rdata <= {24'd0,rx_data};
            STATUS_ADDR: rdata <= {31'd0,valid};
            default:     rdata <= 32'd0;
        endcase
    else
        rdata <= 32'd0;

endmodule
