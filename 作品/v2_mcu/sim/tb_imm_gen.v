`timescale 1ns/1ns

module tb_imm_gen();
reg [31:0] inst;
reg [3:0] instr_type;
wire [31:0] imm;
integer tests, errors;

localparam [3:0]  
    TYPE_INVALID=4'd0, TYPE_ADD=4'd1, TYPE_SUB=4'd2,TYPE_AND=4'd3, TYPE_OR=4'd4, TYPE_XOR=4'd5,
    TYPE_ADDI=4'd6, TYPE_LUI=4'd7, TYPE_LW=4'd8,TYPE_SW=4'd9, TYPE_BEQ=4'd10, TYPE_BNE=4'd11,TYPE_JAL=4'd12, TYPE_JALR=4'd13;

// 预期结果使用常量，不依赖被测模块中的拼接表达式。
task check_imm;
    input [31:0] test_inst;
    input [3:0] test_type;
    input [31:0] expected_imm;
    begin
        inst = test_inst;
        instr_type = test_type;
        #1; // 等待组合逻辑输出稳定；不表示一个时钟周期。
        tests = tests + 1;
        if (imm !== expected_imm) 
            begin
                errors = errors + 1;
                $display("FAIL #%0d: inst=%h type=%0d imm=%h expected=%h", tests, inst, instr_type, imm, expected_imm);
            end
    end
endtask

initial begin
    inst = 0;
    instr_type = TYPE_INVALID;
    tests = 0;
    errors = 0;

    $display("TEST: I format: sign extension and limits");
    // ADDI 立即数 = 0
    check_imm(32'h00008113, TYPE_ADDI, 32'h00000000);
    // ADDI 立即数 = 3
    check_imm(32'h00308113, TYPE_ADDI, 32'h00000003);
    // ADDI 立即数 = -1
    check_imm(32'hFFF08113, TYPE_ADDI, 32'hFFFFFFFF);
    // ADDI 立即数 = -2048
    check_imm(32'h80008113, TYPE_ADDI, 32'hFFFFF800);
    // ADDI 立即数 = 2047
    check_imm(32'h7FF08113, TYPE_ADDI, 32'h000007FF);
    // LW 立即数 = 0
    check_imm(32'h0000A103, TYPE_LW, 32'h00000000);
    // LW 立即数 = 3
    check_imm(32'h0030A103, TYPE_LW, 32'h00000003);
    // LW 立即数 = -1
    check_imm(32'hFFF0A103, TYPE_LW, 32'hFFFFFFFF);
    // LW 立即数 = -2048
    check_imm(32'h8000A103, TYPE_LW, 32'hFFFFF800);
    // LW 立即数 = 2047
    check_imm(32'h7FF0A103, TYPE_LW, 32'h000007FF);
    // JALR 立即数 = 0
    check_imm(32'h00008167, TYPE_JALR, 32'h00000000);
    // JALR 立即数 = 3
    check_imm(32'h00308167, TYPE_JALR, 32'h00000003);
    // JALR 立即数 = -1
    check_imm(32'hFFF08167, TYPE_JALR, 32'hFFFFFFFF);
    // JALR 立即数 = -2048
    check_imm(32'h80008167, TYPE_JALR, 32'hFFFFF800);
    // JALR 立即数 = 2047
    check_imm(32'h7FF08167, TYPE_JALR, 32'h000007FF);

    $display("TEST: S format: both split fields");
    // SW 立即数 = 0
    check_imm(32'h0020A023, TYPE_SW, 32'h00000000);
    // SW 立即数 = 4
    check_imm(32'h0020A223, TYPE_SW, 32'h00000004);
    // SW 立即数 = -4
    check_imm(32'hFE20AE23, TYPE_SW, 32'hFFFFFFFC);
    // SW 立即数 = -2048
    check_imm(32'h8020A023, TYPE_SW, 32'hFFFFF800);
    // SW 立即数 = 2047
    check_imm(32'h7E20AFA3, TYPE_SW, 32'h000007FF);
    // SW 立即数 = 31
    check_imm(32'h0020AFA3, TYPE_SW, 32'h0000001F);
    // SW 立即数 = 32
    check_imm(32'h0220A023, TYPE_SW, 32'h00000020);

    $display("TEST: B format: byte offsets, already shifted");
    // BEQ 立即数 = 0
    check_imm(32'h00208063, TYPE_BEQ, 32'h00000000);
    // BEQ 立即数 = 8
    check_imm(32'h00208463, TYPE_BEQ, 32'h00000008);
    // BEQ 立即数 = -4
    check_imm(32'hFE208EE3, TYPE_BEQ, 32'hFFFFFFFC);
    // BEQ 立即数 = -4096
    check_imm(32'h80208063, TYPE_BEQ, 32'hFFFFF000);
    // BEQ 立即数 = 4094
    check_imm(32'h7E208FE3, TYPE_BEQ, 32'h00000FFE);
    // BEQ 立即数 = 2
    check_imm(32'h00208163, TYPE_BEQ, 32'h00000002);
    // BEQ 立即数 = 16
    check_imm(32'h00208863, TYPE_BEQ, 32'h00000010);
    // BEQ 立即数 = 32
    check_imm(32'h02208063, TYPE_BEQ, 32'h00000020);
    // BEQ 立即数 = 2048
    check_imm(32'h002080E3, TYPE_BEQ, 32'h00000800);
    // BNE 立即数 = 0
    check_imm(32'h00209063, TYPE_BNE, 32'h00000000);
    // BNE 立即数 = 8
    check_imm(32'h00209463, TYPE_BNE, 32'h00000008);
    // BNE 立即数 = -4
    check_imm(32'hFE209EE3, TYPE_BNE, 32'hFFFFFFFC);
    // BNE 立即数 = -4096
    check_imm(32'h80209063, TYPE_BNE, 32'hFFFFF000);
    // BNE 立即数 = 4094
    check_imm(32'h7E209FE3, TYPE_BNE, 32'h00000FFE);
    // BNE 立即数 = 2
    check_imm(32'h00209163, TYPE_BNE, 32'h00000002);
    // BNE 立即数 = 16
    check_imm(32'h00209863, TYPE_BNE, 32'h00000010);
    // BNE 立即数 = 32
    check_imm(32'h02209063, TYPE_BNE, 32'h00000020);
    // BNE 立即数 = 2048
    check_imm(32'h002090E3, TYPE_BNE, 32'h00000800);

    $display("TEST: U format: low 12 bits must be zero");
    // LUI 立即数 = 0
    check_imm(32'h000000B7, TYPE_LUI, 32'h00000000);
    // LUI 立即数 = 305418240
    check_imm(32'h123450B7, TYPE_LUI, 32'h12345000);
    // LUI 立即数 = 2147483648
    check_imm(32'h800000B7, TYPE_LUI, 32'h80000000);
    // LUI 立即数 = 4294963200
    check_imm(32'hFFFFF0B7, TYPE_LUI, 32'hFFFFF000);

    $display("TEST: J format: byte offsets, already shifted");
    // JAL 立即数 = 0
    check_imm(32'h000000EF, TYPE_JAL, 32'h00000000);
    // JAL 立即数 = 8
    check_imm(32'h008000EF, TYPE_JAL, 32'h00000008);
    // JAL 立即数 = -4
    check_imm(32'hFFDFF0EF, TYPE_JAL, 32'hFFFFFFFC);
    // JAL 立即数 = -1048576
    check_imm(32'h800000EF, TYPE_JAL, 32'hFFF00000);
    // JAL 立即数 = 1048574
    check_imm(32'h7FFFF0EF, TYPE_JAL, 32'h000FFFFE);
    // JAL 立即数 = 2
    check_imm(32'h002000EF, TYPE_JAL, 32'h00000002);
    // JAL 立即数 = 1024
    check_imm(32'h400000EF, TYPE_JAL, 32'h00000400);
    // JAL 立即数 = 2048
    check_imm(32'h001000EF, TYPE_JAL, 32'h00000800);
    // JAL 立即数 = 4096
    check_imm(32'h000010EF, TYPE_JAL, 32'h00001000);
    // JAL 立即数 = 524288
    check_imm(32'h000800EF, TYPE_JAL, 32'h00080000);

    $display("TEST: walking one across B/J immediate fields");
    // BEQ：仅将立即数的第 1 位设为 1
    check_imm(32'h00208163, TYPE_BEQ, 32'h00000002);
    // BEQ：仅将立即数的第 2 位设为 1
    check_imm(32'h00208263, TYPE_BEQ, 32'h00000004);
    // BEQ：仅将立即数的第 3 位设为 1
    check_imm(32'h00208463, TYPE_BEQ, 32'h00000008);
    // BEQ：仅将立即数的第 4 位设为 1
    check_imm(32'h00208863, TYPE_BEQ, 32'h00000010);
    // BEQ：仅将立即数的第 5 位设为 1
    check_imm(32'h02208063, TYPE_BEQ, 32'h00000020);
    // BEQ：仅将立即数的第 6 位设为 1
    check_imm(32'h04208063, TYPE_BEQ, 32'h00000040);
    // BEQ：仅将立即数的第 7 位设为 1
    check_imm(32'h08208063, TYPE_BEQ, 32'h00000080);
    // BEQ：仅将立即数的第 8 位设为 1
    check_imm(32'h10208063, TYPE_BEQ, 32'h00000100);
    // BEQ：仅将立即数的第 9 位设为 1
    check_imm(32'h20208063, TYPE_BEQ, 32'h00000200);
    // BEQ：仅将立即数的第 10 位设为 1
    check_imm(32'h40208063, TYPE_BEQ, 32'h00000400);
    // BEQ：仅将立即数的第 11 位设为 1
    check_imm(32'h002080E3, TYPE_BEQ, 32'h00000800);
    // JAL：仅将立即数的第 1 位设为 1
    check_imm(32'h002000EF, TYPE_JAL, 32'h00000002);
    // JAL：仅将立即数的第 2 位设为 1
    check_imm(32'h004000EF, TYPE_JAL, 32'h00000004);
    // JAL：仅将立即数的第 3 位设为 1
    check_imm(32'h008000EF, TYPE_JAL, 32'h00000008);
    // JAL：仅将立即数的第 4 位设为 1
    check_imm(32'h010000EF, TYPE_JAL, 32'h00000010);
    // JAL：仅将立即数的第 5 位设为 1
    check_imm(32'h020000EF, TYPE_JAL, 32'h00000020);
    // JAL：仅将立即数的第 6 位设为 1
    check_imm(32'h040000EF, TYPE_JAL, 32'h00000040);
    // JAL：仅将立即数的第 7 位设为 1
    check_imm(32'h080000EF, TYPE_JAL, 32'h00000080);
    // JAL：仅将立即数的第 8 位设为 1
    check_imm(32'h100000EF, TYPE_JAL, 32'h00000100);
    // JAL：仅将立即数的第 9 位设为 1
    check_imm(32'h200000EF, TYPE_JAL, 32'h00000200);
    // JAL：仅将立即数的第 10 位设为 1
    check_imm(32'h400000EF, TYPE_JAL, 32'h00000400);
    // JAL：仅将立即数的第 11 位设为 1
    check_imm(32'h001000EF, TYPE_JAL, 32'h00000800);
    // JAL：仅将立即数的第 12 位设为 1
    check_imm(32'h000010EF, TYPE_JAL, 32'h00001000);
    // JAL：仅将立即数的第 13 位设为 1
    check_imm(32'h000020EF, TYPE_JAL, 32'h00002000);
    // JAL：仅将立即数的第 14 位设为 1
    check_imm(32'h000040EF, TYPE_JAL, 32'h00004000);
    // JAL：仅将立即数的第 15 位设为 1
    check_imm(32'h000080EF, TYPE_JAL, 32'h00008000);
    // JAL：仅将立即数的第 16 位设为 1
    check_imm(32'h000100EF, TYPE_JAL, 32'h00010000);
    // JAL：仅将立即数的第 17 位设为 1
    check_imm(32'h000200EF, TYPE_JAL, 32'h00020000);
    // JAL：仅将立即数的第 18 位设为 1
    check_imm(32'h000400EF, TYPE_JAL, 32'h00040000);
    // JAL：仅将立即数的第 19 位设为 1
    check_imm(32'h000800EF, TYPE_JAL, 32'h00080000);

    $display("TEST: type changes with identical inst, including defaults");
    // 原始字段测试：直接给定 instr_type，此处不检查操作码。
    check_imm(32'hFFFFFFFF, TYPE_ADDI, 32'hFFFFFFFF);
    // 原始字段测试：直接给定 instr_type，此处不检查操作码。
    check_imm(32'hFFFFFFFF, TYPE_SW, 32'hFFFFFFFF);
    // 原始字段测试：直接给定 instr_type，此处不检查操作码。
    check_imm(32'hFFFFFFFF, TYPE_BEQ, 32'hFFFFFFFE);
    // 原始字段测试：直接给定 instr_type，此处不检查操作码。
    check_imm(32'hFFFFFFFF, TYPE_LUI, 32'hFFFFF000);
    // 原始字段测试：直接给定 instr_type，此处不检查操作码。
    check_imm(32'hFFFFFFFF, TYPE_JAL, 32'hFFFFFFFE);
    // 原始字段测试：直接给定 instr_type，此处不检查操作码。
    check_imm(32'hFFFFFFFF, TYPE_LW, 32'hFFFFFFFF);
    // 原始字段测试：直接给定 instr_type，此处不检查操作码。
    check_imm(32'hFFFFFFFF, TYPE_JALR, 32'hFFFFFFFF);
    // 原始字段测试：直接给定 instr_type，此处不检查操作码。
    check_imm(32'hFFFFFFFF, TYPE_INVALID, 32'h00000000);
    // 原始字段测试：直接给定 instr_type，此处不检查操作码。
    check_imm(32'hFFFFFFFF, TYPE_ADD, 32'h00000000);
    // 原始字段测试：直接给定 instr_type，此处不检查操作码。
    check_imm(32'hFFFFFFFF, TYPE_SUB, 32'h00000000);
    // 原始字段测试：直接给定 instr_type，此处不检查操作码。
    check_imm(32'hFFFFFFFF, TYPE_AND, 32'h00000000);
    // 原始字段测试：直接给定 instr_type，此处不检查操作码。
    check_imm(32'hFFFFFFFF, TYPE_OR, 32'h00000000);
    // 原始字段测试：直接给定 instr_type，此处不检查操作码。
    check_imm(32'hFFFFFFFF, TYPE_XOR, 32'h00000000);
    check_imm(32'hFFFFFFFF, 4'd14, 32'd0);
    check_imm(32'hFFFFFFFF, 4'd15, 32'd0);
    // 从默认类型切换回来，检查能否输出非零立即数
    check_imm(32'hFFF08113, TYPE_ADDI, 32'hFFFFFFFF);
    // 切换回默认类型：不能保留之前的立即数
    check_imm(32'h00000000, TYPE_INVALID, 32'h00000000);

    if (errors == 0)
        $display("tb_imm_gen PASS: checks=%0d", tests);
    else
        $display("tb_imm_gen FAIL: errors=%0d checks=%0d", errors, tests);
    $finish;
end

imm_gen imm_gen_inst
(
    .inst(inst),
    .instr_type(instr_type),
    .imm(imm)
);

endmodule
