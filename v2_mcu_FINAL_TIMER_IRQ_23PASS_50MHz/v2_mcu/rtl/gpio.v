module gpio
(
    input  wire        sys_clk,
    input  wire        sys_rst_n,

    // CPU侧接口：sel由地址译码逻辑产生。
    input  wire        sel,
    input  wire        wen,
    input  wire        ren,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,

    input  wire [7:0]  gpio_in,
    output reg  [7:0]  gpio_out,
    output reg  [31:0] rdata
);

localparam [31:0] GPIO_OUT_ADDR = 32'h1000_0000;
localparam [31:0] GPIO_IN_ADDR  = 32'h1000_0004;

// 两级寄存器同步外部输入；适用于独立的按键或开关信号。
// 同步不等于按键消抖。
reg [7:0] gpio_in_meta;
reg [7:0] gpio_in_sync;

always @(posedge sys_clk or negedge sys_rst_n)
    if (sys_rst_n == 1'b0)
    begin
        gpio_in_meta <= 8'd0;
        gpio_in_sync <= 8'd0;
    end
    else
    begin
        gpio_in_meta <= gpio_in;
        gpio_in_sync <= gpio_in_meta;
    end

// 输出寄存器：选中且写使能有效时，保存写入数据的低8位。
always @(posedge sys_clk or negedge sys_rst_n)
    if (sys_rst_n == 1'b0)
        gpio_out <= 8'd0;
    else if (sel && wen && (addr == GPIO_OUT_ADDR))
        gpio_out <= wdata[7:0];

// 同步读：上升沿采样请求，沿后输出数据，供CPU下一拍写回。
// 未选中、未读或地址无效时返回0；未对齐地址不会匹配。
// 同沿读写输出寄存器时，读回写入前的旧值。
always @(posedge sys_clk or negedge sys_rst_n)
    if (sys_rst_n == 1'b0)
        rdata <= 32'd0;
    else if (sel && ren)
        case (addr)
            GPIO_OUT_ADDR: rdata <= {24'd0, gpio_out};
            GPIO_IN_ADDR:  rdata <= {24'd0, gpio_in_sync};
            default:       rdata <= 32'd0;
        endcase
    else
        rdata <= 32'd0;

endmodule
