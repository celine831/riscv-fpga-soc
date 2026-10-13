module fpga_top
#(
    // 征途Pro常见板载时钟为50 MHz。
    // 计数器第25位大约每0.67秒翻转一次，肉眼可以看到闪烁。
    parameter HEARTBEAT_BIT  = 25,

    // LED高电平点亮时设为0；LED低电平点亮时改为1。
    parameter LED_ACTIVE_LOW = 1,

    // 5=Timer中断+双向UART；4=双向UART；3=UART TX；2=Timer；1=GPIO。
    parameter ROM_PROGRAM = 5,
    parameter [31:0] TIMER_DEMO_PERIOD = 32'd25_000_000,
    parameter integer UART_CLKS_PER_BIT = 434
)
(
    input  wire sys_clk,
    input  wire sys_rst_n,

    output wire led_run,
    output wire led_done,
    output wire uart_tx_pin,
    input  wire uart_rx_pin
);

// ============================================================
// 1. 复位同步
// ============================================================
// 按下复位键时异步复位；松开复位键时经过两个时钟再释放。
reg [1:0] rst_sync;

always @(posedge sys_clk or negedge sys_rst_n)
begin
    if (sys_rst_n == 1'b0)
        rst_sync <= 2'b00;
    else
        rst_sync <= {rst_sync[0], 1'b1};
end

wire cpu_rst_n;
assign cpu_rst_n = rst_sync[1];

// ============================================================
// 2. CPU核心
// ============================================================
wire [31:0] pc;
wire [31:0] inst;
wire [31:0] alu_result;
wire [31:0] wb_data;

wire [7:0] gpio_out;

cpu_top #(.ROM_PROGRAM(ROM_PROGRAM),
          .TIMER_DEMO_PERIOD(TIMER_DEMO_PERIOD),
          .UART_CLKS_PER_BIT(UART_CLKS_PER_BIT)) cpu_top_inst
(
    .sys_clk    (sys_clk),
    .sys_rst_n  (cpu_rst_n),
    .pc         (pc),
    .inst       (inst),
    .alu_result (alu_result),
    .wb_data    (wb_data),
    .gpio_in    (8'd0),
    .gpio_out   (gpio_out),
    .uart_tx_pin(uart_tx_pin),
    .uart_rx_pin(uart_rx_pin)
);

// ============================================================
// 3. 运行心跳灯
// ============================================================
// CPU仍使用板载时钟全速运行；这里只对时钟计数供LED观察。
reg [31:0] heartbeat_cnt;

always @(posedge sys_clk or negedge cpu_rst_n)
begin
    if (cpu_rst_n == 1'b0)
        heartbeat_cnt <= 32'd0;
    else
        heartbeat_cnt <= heartbeat_cnt + 32'd1;
end

wire led_run_value;
assign led_run_value = heartbeat_cnt[HEARTBEAT_BIT];

// ============================================================
// 4. CPU通过SW指令写GPIO，从而控制第二个LED。
// 本顶层没有新增按键端口，GPIO输入先接0；外部输入由仿真覆盖。
// led_run是心跳；led_done由GPIO bit0控制，不再检测PC。
// ============================================================
assign led_run  = (LED_ACTIVE_LOW == 0) ? led_run_value : ~led_run_value;
assign led_done = (LED_ACTIVE_LOW == 0) ? gpio_out[0] : ~gpio_out[0];

endmodule
