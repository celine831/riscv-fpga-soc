`timescale 1ns/1ns

module tb_control_unit;

reg        sys_rst_n;
reg  [3:0] instr_type;

wire       reg_wen;
wire       mem_wen;
wire       alu_src_imm;
wire [2:0] alu_op;
wire [1:0] wb_sel;

integer checks;
integer errors;

// 必须与decoder.v、imm_gen.v和control_unit.v中的编码一致
localparam [3:0]
    TYPE_INVALID = 4'd0,
    TYPE_ADD     = 4'd1,
    TYPE_SUB     = 4'd2,
    TYPE_AND     = 4'd3,
    TYPE_OR      = 4'd4,
    TYPE_XOR     = 4'd5,
    TYPE_ADDI    = 4'd6,
    TYPE_LUI     = 4'd7,
    TYPE_LW      = 4'd8,
    TYPE_SW      = 4'd9,
    TYPE_BEQ     = 4'd10,
    TYPE_BNE     = 4'd11,
    TYPE_JAL     = 4'd12,
    TYPE_JALR    = 4'd13,
    TYPE_CSR     = 4'd14,
    TYPE_MRET    = 4'd15;

// 必须与alu.v和control_unit.v中的编码一致
localparam [2:0]
    ALU_ADD = 3'b000,
    ALU_SUB = 3'b001,
    ALU_AND = 3'b010,
    ALU_OR  = 3'b011,
    ALU_XOR = 3'b100;

// 必须与control_unit.v中的写回来源编码一致
localparam [1:0]
    WB_ALU = 2'b00,
    WB_MEM = 2'b01,
    WB_IMM = 2'b10,
    WB_PC4 = 2'b11;

// 被测试模块
control_unit dut
(
    .sys_rst_n  (sys_rst_n),
    .instr_type (instr_type),
    .reg_wen    (reg_wen),
    .mem_wen    (mem_wen),
    .alu_src_imm(alu_src_imm),
    .alu_op     (alu_op),
    .wb_sel     (wb_sel)
);

// 检查一组控制信号是否全部符合预期
task check_control;
    input [3:0]  test_instr_type;
    input        expected_reg_wen;
    input        expected_mem_wen;
    input        expected_alu_src_imm;
    input [2:0]  expected_alu_op;
    input [1:0]  expected_wb_sel;
    input [8*64-1:0] test_name;
    begin
        instr_type = test_instr_type;
        #1;
        checks = checks + 1;

        if ((reg_wen     !== expected_reg_wen)     ||
            (mem_wen     !== expected_mem_wen)     ||
            (alu_src_imm !== expected_alu_src_imm) ||
            (alu_op      !== expected_alu_op)      ||
            (wb_sel      !== expected_wb_sel))
        begin
            errors = errors + 1;
            $display("[FAIL] %0s", test_name);
            $display("       expected: reg_wen=%b mem_wen=%b alu_src_imm=%b alu_op=%b wb_sel=%b",
                     expected_reg_wen, expected_mem_wen, expected_alu_src_imm,
                     expected_alu_op, expected_wb_sel);
            $display("       actual  : reg_wen=%b mem_wen=%b alu_src_imm=%b alu_op=%b wb_sel=%b",
                     reg_wen, mem_wen, alu_src_imm, alu_op, wb_sel);
        end
        else
        begin
            $display("[PASS] %0s", test_name);
        end
    end
endtask

initial
begin
    sys_rst_n  = 1'b0;
    instr_type = TYPE_INVALID;
    checks     = 0;
    errors     = 0;

    // ------------------------------------------------------------
    // TEST 1：复位期间禁止所有写操作
    // 即使输入SW或ADD，输出也必须保持安全默认值
    // ------------------------------------------------------------
    $display("\nTEST 1: reset disables all writes");
    check_control(TYPE_SW,
                  1'b0, 1'b0, 1'b0, ALU_ADD, WB_ALU,
                  "reset with SW input");

    check_control(TYPE_ADD,
                  1'b0, 1'b0, 1'b0, ALU_ADD, WB_ALU,
                  "reset with ADD input");

    // 释放复位，control_unit为组合逻辑，不需要等待时钟
    sys_rst_n = 1'b1;
    #1;

    // ------------------------------------------------------------
    // TEST 2：无效编码无写操作；CSR写旧值到rd，MRET不写通用寄存器
    // ------------------------------------------------------------
    $display("\nTEST 2: invalid instruction types");
    check_control(TYPE_INVALID,
                  1'b0, 1'b0, 1'b0, ALU_ADD, WB_ALU,
                  "TYPE_INVALID");

    check_control(TYPE_CSR,
                  1'b1, 1'b0, 1'b0, ALU_ADD, WB_ALU,
                  "CSR writes old value to rd");

    check_control(TYPE_MRET,
                  1'b0, 1'b0, 1'b0, ALU_ADD, WB_ALU,
                  "MRET does not write general registers");

    // ------------------------------------------------------------
    // TEST 3：R型算术逻辑指令
    // ------------------------------------------------------------
    $display("\nTEST 3: R-type instructions");
    check_control(TYPE_ADD,
                  1'b1, 1'b0, 1'b0, ALU_ADD, WB_ALU,
                  "ADD control signals");

    check_control(TYPE_SUB,
                  1'b1, 1'b0, 1'b0, ALU_SUB, WB_ALU,
                  "SUB control signals");

    check_control(TYPE_AND,
                  1'b1, 1'b0, 1'b0, ALU_AND, WB_ALU,
                  "AND control signals");

    check_control(TYPE_OR,
                  1'b1, 1'b0, 1'b0, ALU_OR, WB_ALU,
                  "OR control signals");

    check_control(TYPE_XOR,
                  1'b1, 1'b0, 1'b0, ALU_XOR, WB_ALU,
                  "XOR control signals");

    // ------------------------------------------------------------
    // TEST 4：立即数指令和高位立即数指令
    // ------------------------------------------------------------
    $display("\nTEST 4: immediate instructions");
    check_control(TYPE_ADDI,
                  1'b1, 1'b0, 1'b1, ALU_ADD, WB_ALU,
                  "ADDI control signals");

    check_control(TYPE_LUI,
                  1'b1, 1'b0, 1'b0, ALU_ADD, WB_IMM,
                  "LUI control signals");

    // ------------------------------------------------------------
    // TEST 5：数据存储器访问指令
    // ------------------------------------------------------------
    $display("\nTEST 5: load/store instructions");
    check_control(TYPE_LW,
                  1'b1, 1'b0, 1'b1, ALU_ADD, WB_MEM,
                  "LW control signals");

    check_control(TYPE_SW,
                  1'b0, 1'b1, 1'b1, ALU_ADD, WB_ALU,
                  "SW control signals");

    // ------------------------------------------------------------
    // TEST 6：条件分支指令
    // BEQ/BNE使用减法比较rs1和rs2，不写寄存器或RAM
    // ------------------------------------------------------------
    $display("\nTEST 6: branch instructions");
    check_control(TYPE_BEQ,
                  1'b0, 1'b0, 1'b0, ALU_SUB, WB_ALU,
                  "BEQ control signals");

    check_control(TYPE_BNE,
                  1'b0, 1'b0, 1'b0, ALU_SUB, WB_ALU,
                  "BNE control signals");

    // ------------------------------------------------------------
    // TEST 7：无条件跳转指令
    // JAL/JALR均把PC+4写入rd
    // ------------------------------------------------------------
    $display("\nTEST 7: jump instructions");
    check_control(TYPE_JAL,
                  1'b1, 1'b0, 1'b0, ALU_ADD, WB_PC4,
                  "JAL control signals");

    check_control(TYPE_JALR,
                  1'b1, 1'b0, 1'b1, ALU_ADD, WB_PC4,
                  "JALR control signals");

    // ------------------------------------------------------------
    // TEST 8：工作期间异步拉低复位
    // ------------------------------------------------------------
    $display("\nTEST 8: reset priority during operation");
    instr_type = TYPE_SW;
    #1;
    sys_rst_n = 1'b0;
    check_control(TYPE_SW,
                  1'b0, 1'b0, 1'b0, ALU_ADD, WB_ALU,
                  "reset immediately disables SW");

    // ------------------------------------------------------------
    // 测试结果汇总
    // ------------------------------------------------------------
    $display("\n========================================");
    if (errors == 0)
        $display("tb_control_unit PASS: checks=%0d", checks);
    else
        $display("tb_control_unit FAIL: checks=%0d, errors=%0d", checks, errors);
    $display("========================================\n");

    $finish;
end

endmodule
