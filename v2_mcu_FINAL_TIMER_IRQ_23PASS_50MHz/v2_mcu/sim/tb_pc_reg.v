`timescale 1ns/1ps

module tb_pc_reg;

reg         sys_clk;
reg         sys_rst_n;
reg  [31:0] pc_next;
wire [31:0] pc;

integer checks;
integer errors;

// 被测试模块
pc_reg dut
(
    .sys_clk   (sys_clk),
    .sys_rst_n (sys_rst_n),
    .pc_next   (pc_next),
    .pc        (pc)
);

// 10 ns时钟周期，对应100 MHz
initial
begin
    sys_clk = 1'b0;
    forever #5 sys_clk = ~sys_clk;
end

// 自动检查PC是否等于期望值
task check_pc;
    input [31:0] expected;
    input [8*64-1:0] test_name;
    begin
        #1;
        checks = checks + 1;
        if (pc !== expected)
        begin
            errors = errors + 1;
            $display("[FAIL] %0s: expected_pc=%h, actual_pc=%h, time=%0t",
                     test_name, expected, pc, $time);
        end
        else
        begin
            $display("[PASS] %0s: pc=%h", test_name, pc);
        end
    end
endtask

initial
begin
    sys_rst_n = 1'b1;
    pc_next    = 32'd0;
    checks     = 0;
    errors     = 0;

    // ------------------------------------------------------------
    // TEST 1：异步低电平复位，不等待时钟就把PC清零
    // ------------------------------------------------------------
    $display("\nTEST 1: asynchronous reset");
    #2;
    sys_rst_n = 1'b0;
    check_pc(32'd0, "PC becomes zero immediately during reset");

    // 复位期间，即使pc_next不是0，PC仍然必须保持0
    pc_next = 32'h1234_5678;
    @(posedge sys_clk);
    check_pc(32'd0, "PC stays zero on rising edge during reset");

    // ------------------------------------------------------------
    // TEST 2：释放复位本身不会立即改变PC
    // ------------------------------------------------------------
    $display("\nTEST 2: release reset");
    @(negedge sys_clk);
    sys_rst_n = 1'b1;
    check_pc(32'd0, "releasing reset does not immediately change PC");

    // ------------------------------------------------------------
    // TEST 3：PC只在时钟上升沿采样pc_next
    // ------------------------------------------------------------
    $display("\nTEST 3: update PC on rising edge");
    pc_next = 32'd4;
    check_pc(32'd0, "PC keeps old value before rising edge");

    @(posedge sys_clk);
    check_pc(32'd4, "PC captures 4 on rising edge");

    // ------------------------------------------------------------
    // TEST 4：pc_next在两个上升沿之间改变，PC不能提前改变
    // ------------------------------------------------------------
    $display("\nTEST 4: PC holds value between rising edges");
    @(negedge sys_clk);
    pc_next = 32'd8;
    check_pc(32'd4, "PC still holds 4 before next rising edge");

    @(posedge sys_clk);
    check_pc(32'd8, "PC captures 8 on next rising edge");

    // ------------------------------------------------------------
    // TEST 5：PC能够接收任意32位下一地址
    // ------------------------------------------------------------
    $display("\nTEST 5: arbitrary next PC value");
    @(negedge sys_clk);
    pc_next = 32'h0000_0100;
    @(posedge sys_clk);
    check_pc(32'h0000_0100, "PC captures address 0x00000100");

    // ------------------------------------------------------------
    // TEST 6：工作过程中异步复位，优先于正常PC更新
    // ------------------------------------------------------------
    $display("\nTEST 6: asynchronous reset priority");
    @(negedge sys_clk);
    pc_next = 32'hDEAD_BEEF;
    #2;
    sys_rst_n = 1'b0;
    check_pc(32'd0, "asynchronous reset clears running PC immediately");

    @(posedge sys_clk);
    check_pc(32'd0, "reset has priority over pc_next on rising edge");

    // ------------------------------------------------------------
    // TEST 7：复位结束后恢复正常更新
    // ------------------------------------------------------------
    $display("\nTEST 7: resume after reset");
    @(negedge sys_clk);
    sys_rst_n = 1'b1;
    pc_next    = 32'h0000_0040;
    @(posedge sys_clk);
    check_pc(32'h0000_0040, "PC resumes updating after reset");

    // ------------------------------------------------------------
    // 测试结果汇总
    // ------------------------------------------------------------
    $display("\n========================================");
    if (errors == 0)
        $display("tb_pc_reg PASS: checks=%0d", checks);
    else
        $display("tb_pc_reg FAIL: checks=%0d, errors=%0d", checks, errors);
    $display("========================================\n");

    $finish;
end

endmodule
