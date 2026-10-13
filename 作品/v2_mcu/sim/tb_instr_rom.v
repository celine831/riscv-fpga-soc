`timescale 1ns/1ps

module tb_instr_rom;

reg         sys_rst_n;
reg  [31:0] addr;
wire [31:0] inst;

integer checks;
integer errors;

// ============================================================
// 指令ROM实例化
// ============================================================
instr_rom instr_rom_inst
(
    .sys_rst_n (sys_rst_n),
    .addr      (addr),
    .inst      (inst)
);

// ============================================================
// 自动检查任务
// ============================================================
task check_inst;
    input [31:0]     test_addr;
    input [31:0]     expected_inst;
    input [8*80-1:0] test_name;

    begin
        addr = test_addr;
        #1;

        checks = checks + 1;

        if (inst === expected_inst)
        begin
            $display(
                "[PASS] %0s: addr=%h inst=%h",
                test_name,
                addr,
                inst
            );
        end
        else
        begin
            errors = errors + 1;

            $display(
                "[FAIL] %0s: addr=%h inst=%h expected=%h",
                test_name,
                addr,
                inst,
                expected_inst
            );
        end
    end
endtask

// ============================================================
// 测试过程
// ============================================================
initial
begin
    checks    = 0;
    errors    = 0;
    sys_rst_n = 1'b0;
    addr      = 32'h0000_0000;

    // ========================================================
    // TEST 1：复位期间必须输出NOP
    // ========================================================
    $display("\nTEST 1: reset output");

    check_inst(
        32'h0000_0000,
        32'h0000_0013,
        "reset outputs NOP"
    );

    // 释放复位
    sys_rst_n = 1'b1;
    #1;

    // ========================================================
    // TEST 2：检查全部程序指令
    // ========================================================
    $display("\nTEST 2: complete instruction program");

    check_inst(
        32'h0000_0000,
        32'h00A0_0093,
        "addi x1,x0,10"
    );

    check_inst(
        32'h0000_0004,
        32'h0030_0113,
        "addi x2,x0,3"
    );

    check_inst(
        32'h0000_0008,
        32'h0020_81B3,
        "add x3,x1,x2"
    );

    check_inst(
        32'h0000_000C,
        32'h4020_8233,
        "sub x4,x1,x2"
    );

    check_inst(
        32'h0000_0010,
        32'h0020_F2B3,
        "and x5,x1,x2"
    );

    check_inst(
        32'h0000_0014,
        32'h0020_E333,
        "or x6,x1,x2"
    );

    check_inst(
        32'h0000_0018,
        32'h0020_C3B3,
        "xor x7,x1,x2"
    );

    check_inst(
        32'h0000_001C,
        32'h1234_5437,
        "lui x8,0x12345"
    );

    check_inst(
        32'h0000_0020,
        32'h0030_2023,
        "sw x3,0(x0)"
    );

    check_inst(
        32'h0000_0024,
        32'h0000_2483,
        "lw x9,0(x0)"
    );

    check_inst(
        32'h0000_0028,
        32'h0034_8463,
        "beq x9,x3,+8"
    );

    check_inst(
        32'h0000_002C,
        32'h0010_0513,
        "addi x10,x0,1"
    );

    check_inst(
        32'h0000_0030,
        32'h0020_9463,
        "bne x1,x2,+8"
    );

    check_inst(
        32'h0000_0034,
        32'h0010_0593,
        "addi x11,x0,1"
    );

    check_inst(
        32'h0000_0038,
        32'h0080_066F,
        "jal x12,+8"
    );

    check_inst(
        32'h0000_003C,
        32'h0010_0693,
        "addi x13,x0,1"
    );

    check_inst(
        32'h0000_0040,
        32'h04C0_0713,
        "addi x14,x0,76"
    );

    check_inst(
        32'h0000_0044,
        32'h0007_07E7,
        "jalr x15,0(x14)"
    );

    check_inst(
        32'h0000_0048,
        32'h0010_0813,
        "addi x16,x0,1"
    );

    check_inst(
        32'h0000_004C,
        32'h01F0_0893,
        "addi x17,x0,31"
    );

    // ========================================================
    // TEST 3：未使用地址输出NOP
    // ========================================================
    $display("\nTEST 3: unused addresses");

    check_inst(
        32'h0000_0050,
        32'h0000_006F,
        "program end outputs JAL x0,0"
    );

    check_inst(
        32'h0000_0100,
        32'h0000_0013,
        "out-of-program address outputs NOP"
    );

    check_inst(
        32'h0000_0001,
        32'h0000_0013,
        "misaligned address outputs NOP"
    );

    // ========================================================
    // TEST 4：运行过程中再次复位
    // ========================================================
    $display("\nTEST 4: reset priority");

    addr = 32'h0000_001C;
    #1;

    sys_rst_n = 1'b0;
    #1;

    checks = checks + 1;

    if (inst === 32'h0000_0013)
    begin
        $display(
            "[PASS] reset immediately forces NOP: inst=%h",
            inst
        );
    end
    else
    begin
        errors = errors + 1;

        $display(
            "[FAIL] reset immediately forces NOP: inst=%h expected=00000013",
            inst
        );
    end

    // ========================================================
    // 最终结果
    // ========================================================
    $display("\n========================================");

    if (errors == 0)
    begin
        $display(
            "tb_instr_rom PASS: checks=%0d",
            checks
        );
    end
    else
    begin
        $display(
            "tb_instr_rom FAIL: checks=%0d errors=%0d",
            checks,
            errors
        );
    end

    $display("========================================\n");

    $finish;
end

endmodule