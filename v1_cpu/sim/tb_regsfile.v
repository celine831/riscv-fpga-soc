`timescale 1ns/1ns

module tb_regsfile();

reg         sys_clk;
reg         sys_rst_n;
reg         wen;
reg  [4:0]  waddr;
reg  [31:0] wdata;
reg  [4:0]  raddr1;
reg  [4:0]  raddr2;

wire [31:0] rdata1;
wire [31:0] rdata2;

integer errors;
integer i;


// 50 MHz 时钟
initial 
    begin
        sys_clk = 1'b0;
        sys_rst_n<=1'b0;
        #20;
        sys_rst_n<=1'b1;
    end
    
always #10 sys_clk = ~sys_clk;


// 写入一次寄存器
task write_reg;
    input [4:0]  addr;
    input [31:0] data;
    begin
        // 下降沿准备地址、数据和写使能
        @(negedge sys_clk);
        wen   = 1'b1;
        waddr = addr;
        wdata = data;

        // 下一个上升沿执行写入
        @(posedge sys_clk);
        #1;

        // 写完后，在下降沿关闭写使能
        @(negedge sys_clk);
        wen = 1'b0;
    end
endtask


// 自动检查两个读端口的结果
task check_data;
    input [31:0] expected1;
    input [31:0] expected2;
    begin
        // 留出组合逻辑更新时间
        #1;

        if (rdata1 !== expected1) 
            begin
                errors = errors + 1;
                $display(
                    "FAIL t=%0t port1 addr=%0d expected=%h actual=%h",
                    $time, raddr1, expected1, rdata1
                );
            end

        if (rdata2 !== expected2) 
            begin
                errors = errors + 1;
                $display(
                    "FAIL t=%0t port2 addr=%0d expected=%h actual=%h",
                    $time, raddr2, expected2, rdata2
                );
            end
    end
endtask


initial 
begin
        errors    = 0;
        sys_rst_n = 1'b1;
        wen       = 1'b0;
        waddr     = 5'd0;
        wdata     = 32'd0;
        raddr1    = 5'd0;
        raddr2    = 5'd0;

    // ========================================
    // TEST 1：复位后，全部寄存器读出 0
    // ========================================
    $display("TEST 1: reset");

    #1;
    sys_rst_n = 1'b0;

    for (i = 0; i < 32; i = i + 1) begin
        raddr1 = i;
        raddr2 = 31 - i;
        check_data(32'd0, 32'd0);
    end

    @(negedge sys_clk);
    sys_rst_n = 1'b1;

    // ========================================
    // TEST 2：写入两个寄存器，同时读取
    // ========================================
    $display("TEST 2: write and dual read");

    write_reg(5'd1, 32'd5);
    write_reg(5'd2, 32'd8);

    raddr1 = 5'd1;
    raddr2 = 5'd2;
    check_data(32'd5, 32'd8);

    // 交换两个读地址，不等待时钟上升沿
    raddr1 = 5'd2;
    raddr2 = 5'd1;
    check_data(32'd8, 32'd5);

    // ========================================
    // TEST 3：wen=0，不能修改寄存器
    // ========================================
    $display("TEST 3: write disabled");

    @(negedge sys_clk);
    wen    = 1'b0;
    waddr  = 5'd1;
    wdata  = 32'd99;
    raddr1 = 5'd1;
    raddr2 = 5'd2;

    @(posedge sys_clk);
    check_data(32'd5, 32'd8);

    // ========================================
    // TEST 4：尝试写 x0，仍然读出 0
    // ========================================
    $display("TEST 4: x0 protection");

    write_reg(5'd0, 32'hFFFFFFFF);

    raddr1 = 5'd0;
    raddr2 = 5'd0;
    check_data(32'd0, 32'd0);

    // ========================================
    // TEST 5：同地址读写
    // 上升沿前读旧值，上升沿更新后读新值
    // ========================================
    $display("TEST 5: same-address read and write");

    @(negedge sys_clk);
    wen    = 1'b1;
    waddr  = 5'd1;
    wdata  = 32'd9;
    raddr1 = 5'd1;
    raddr2 = 5'd1;

    // 尚未到写入上升沿，x1 应该仍为 5
    check_data(32'd5, 32'd5);

    @(posedge sys_clk);

    // check_data 内部等待 1 ns，再检查更新后的值
    check_data(32'd9, 32'd9);

    @(negedge sys_clk);
    wen = 1'b0;

    // ========================================
    // TEST 6：检查 x1～x31 全部地址
    // 每个地址写入不同数据，检查是否写错位置
    // ========================================
    $display("TEST 6: all register addresses");

    for (i = 1; i < 32; i = i + 1)
        write_reg(i, 32'hA5000000 + i);

    for (i = 1; i < 32; i = i + 1) begin
        raddr1 = i;
        raddr2 = 32 - i;

        check_data(
            32'hA5000000 + i,
            32'hA5000000 + (32 - i)
        );
    end

    // ========================================
    // TEST 7：运行中异步复位，且复位优先于写入
    // ========================================
    $display("TEST 7: asynchronous reset and priority");

    @(negedge sys_clk);
    wen    = 1'b1;
    waddr  = 5'd2;
    wdata  = 32'd99;
    raddr1 = 5'd1;
    raddr2 = 5'd2;

    // 在两个时钟边沿之间拉低复位
    #3;
    sys_rst_n = 1'b0;

    // 不等上升沿，应该已经清零
    check_data(32'd0, 32'd0);

    // 复位保持有效，即使 wen=1 也不能写入
    @(posedge sys_clk);
    check_data(32'd0, 32'd0);

    // 检查全部地址均被清零
    for (i = 0; i < 32; i = i + 1) begin
        raddr1 = i;
        raddr2 = 31 - i;
        check_data(32'd0, 32'd0);
    end

    @(negedge sys_clk);
    wen       = 1'b0;
    sys_rst_n = 1'b1;

    // 复位释放后，重新写入应正常
    write_reg(5'd31, 32'h12345678);

    raddr1 = 5'd31;
    raddr2 = 5'd0;
    check_data(32'h12345678, 32'd0);

    // ========================================
    // 汇总结果
    // ========================================
    if (errors == 0)
        $display("PASS: all regsfile tests passed.");
    else
        $display("FAIL: %0d errors detected.", errors);

    $stop;
end


regsfile regsfile_inst (
    .sys_clk   (sys_clk),
    .sys_rst_n (sys_rst_n),

    .wen       (wen),
    .waddr     (waddr),
    .wdata     (wdata),

    .raddr1    (raddr1),
    .raddr2    (raddr2),
    .rdata1    (rdata1),
    .rdata2    (rdata2)
);


endmodule