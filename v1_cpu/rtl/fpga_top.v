module fpga_top
#(
    // 征途Pro常见板载时钟为50 MHz。
    // 计数器第25位大约每0.67秒翻转一次，肉眼可以看到闪烁。
    parameter HEARTBEAT_BIT  = 25,

    // LED高电平点亮时设为0；LED低电平点亮时改为1。
    parameter LED_ACTIVE_LOW = 1
)
(
    input  wire sys_clk,
    input  wire sys_rst_n,

    output wire led_run,
    output wire led_done
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

cpu_top cpu_top_inst
(
    .sys_clk    (sys_clk),
    .sys_rst_n  (cpu_rst_n),
    .pc         (pc),
    .inst       (inst),
    .alu_result (alu_result),
    .wb_data    (wb_data)
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
// 4. 程序完成指示灯
// ============================================================
// 当CPU到达0x50时锁存完成状态；只有复位才会熄灭。
reg program_done;

always @(posedge sys_clk or negedge cpu_rst_n)
begin
    if (cpu_rst_n == 1'b0)
        program_done <= 1'b0;
    else if (pc == 32'h0000_0050)
        program_done <= 1'b1;
end

// 根据板上LED是高电平点亮还是低电平点亮选择极性。
assign led_run  = (LED_ACTIVE_LOW == 0) ? led_run_value : ~led_run_value;
assign led_done = (LED_ACTIVE_LOW == 0) ? program_done  : ~program_done;

endmodule

