`timescale 1ns/1ns

module tb_decoder();

reg  [31:0] inst;

wire [4:0] rs1_addr;
wire [4:0] rs2_addr;
wire [4:0] rd_addr;
wire [3:0] instr_type;
wire       illegal;

integer errors;
integer tests;


// 输入一条机器码，检查指令类型和 illegal
task check_decode;
    input [31:0] test_inst;
    input [3:0]  expected_type;
    input        expected_illegal;

    begin
        inst = test_inst;
        #1;

        tests = tests + 1;

        if ((instr_type !== expected_type) ||
            (illegal !== expected_illegal)) 
            begin

                errors = errors + 1;

                $display(
                    "FAIL decode: inst=%h,type= %0d,expected type= %0d,illegal= %b,expected illegal= %b",
                    inst, instr_type, expected_type,
                    illegal, expected_illegal
                );
            end
    end
endtask

// 检查当前机器码中提取出的三个地址字段
task check_addr;
    input [4:0] expected_rs1;
    input [4:0] expected_rs2;
    input [4:0] expected_rd;

    begin
        #1;
        tests = tests + 1;

        if ((rs1_addr !== expected_rs1) ||
            (rs2_addr !== expected_rs2) ||
            (rd_addr  !== expected_rd)) 
            begin        
                errors = errors + 1;       
                $display(
                    "FAIL addr: inst=%h rs1=%0d rs2=%0d rd=%0d; expected=%0d,%0d,%0d",
                    inst, rs1_addr, rs2_addr, rd_addr,
                    expected_rs1, expected_rs2, expected_rd
                );
            end
    end
endtask


initial 
    begin
        inst   = 32'd0;
        errors = 0;
        tests  = 0;

        // ------------------------------------------------
        // TEST 1：本项目支持的全部 13 条指令
        // ------------------------------------------------
        $display("TEST 1: all 13 supported instructions");

        // add x3, x1, x2
        check_decode(32'h002081B3, 4'd1, 1'b0);
        check_addr(5'd1, 5'd2, 5'd3);

        // sub x3, x1, x2
        check_decode(32'h402081B3, 4'd2, 1'b0);

        // and x3, x1, x2
        check_decode(32'h0020F1B3, 4'd3, 1'b0);

        // or x3, x1, x2
        check_decode(32'h0020E1B3, 4'd4, 1'b0);

        // xor x3, x1, x2
        check_decode(32'h0020C1B3, 4'd5, 1'b0);

        // addi x2, x1, 3
        check_decode(32'h00308113, 4'd6, 1'b0);

        // ADDI 不使用 rs2。
        // 这里的 3 只是 inst[24:20] 的原始提取结果。
        check_addr(5'd1, 5'd3, 5'd2);

        // lui x1, 0x12345
        check_decode(32'h123450B7, 4'd7, 1'b0);

        // lw x2, 4(x1)
        check_decode(32'h0040A103, 4'd8, 1'b0);

        // sw x2, 4(x1)
        check_decode(32'h0020A223, 4'd9, 1'b0);

        // SW 不使用 rd。
        // 此处 rd_addr=4 来自立即数字段，不表示写 x4。
        check_addr(5'd1, 5'd2, 5'd4);

        // beq x1, x2, 当前 PC + 8
        check_decode(32'h00208463, 4'd10, 1'b0);

        // bne x1, x2, 当前 PC + 8
        check_decode(32'h00209463, 4'd11, 1'b0);

        // jal x1, 当前 PC + 8
        check_decode(32'h008000EF, 4'd12, 1'b0);

        // jalr x2, 0(x1)
        check_decode(32'h00008167, 4'd13, 1'b0);

        // ------------------------------------------------
        // TEST 2：寄存器地址边界、三个地址彼此独立（防止rs1，rs2，rd三个位置写错）
        // ------------------------------------------------
        $display("TEST 2: register address fields");

        // add x31, x0, x1
        check_decode(32'h00100FB3, 4'd1, 1'b0);
        check_addr(5'd0, 5'd1, 5'd31);

        // add x0, x31, x30
        // rd=x0 仍是合法指令，由寄存器堆忽略写入。
        check_decode(32'h01EF8033, 4'd1, 1'b0);
        check_addr(5'd31, 5'd30, 5'd0);

        // ------------------------------------------------
        // TEST 3：立即数不能被错误地当成功能码限制
        // ------------------------------------------------
        $display("TEST 3: immediate fields");

        // addi x2, x1, -1
        // 高 7 位不是 0，依然是 ADDI。
        check_decode(32'hFFF08113, 4'd6, 1'b0);

        // addi x2, x1, -2048
        check_decode(32'h80008113, 4'd6, 1'b0);

        // addi x2, x1, 2047
        check_decode(32'h7FF08113, 4'd6, 1'b0);//对于addi，[31:20] 全是立即数,没有fun7限制，如果写错，通过这三个立即数可检查出

        // lw x2, -4(x1)
        check_decode(32'hFFC0A103, 4'd8, 1'b0);

        // sw x2, -4(x1)
        check_decode(32'hFE20AE23, 4'd9, 1'b0);

        // jalr x2, -4(x1)
        check_decode(32'hFFC08167, 4'd13, 1'b0);

        // lui x1, 0xFFFFF
        // LUI 没有 funct3、funct7，不能检查这些位置。
        check_decode(32'hFFFFF0B7, 4'd7, 1'b0);

        // jal x1, 当前 PC - 4
        // JAL 没有 funct3、funct7。
        check_decode(32'hFFDFF0EF, 4'd12, 1'b0);

        // beq x1, x2, 当前 PC - 4
        check_decode(32'hFE208EE3, 4'd10, 1'b0);

        // bne x1, x2, 当前 PC - 4
        check_decode(32'hFE209EE3, 4'd11, 1'b0);

        // ------------------------------------------------
        // TEST 4：不支持的指令或编码
        // ------------------------------------------------
        $display("TEST 4: unsupported encodings");

        check_decode(32'h00000000, 4'd0, 1'b1);
        check_decode(32'hFFFFFFFF, 4'd0, 1'b1);

        // SLL：合法 RV32I 指令，但本项目没有实现
        check_decode(32'h002091B3, 4'd0, 1'b1);

        // MUL：属于 M 扩展，不能误识别为 ADD
        check_decode(32'h022081B3, 4'd0, 1'b1);

        // funct3 与 AND 相同，但 funct7 错误
        check_decode(32'h4020F1B3, 4'd0, 1'b1);

        // funct3 与 OR 相同，但 funct7 错误
        check_decode(32'h4020E1B3, 4'd0, 1'b1);

        // funct3 与 XOR 相同，但 funct7 错误
        check_decode(32'h4020C1B3, 4'd0, 1'b1);

        // ORI：本项目没有实现，不能误识别为 ADDI
        check_decode(32'h0030E113, 4'd0, 1'b1);

        // LB：本项目只实现 LW
        check_decode(32'h00408103, 4'd0, 1'b1);

        // SB：本项目只实现 SW
        check_decode(32'h00208223, 4'd0, 1'b1);

        // BLT：本项目只实现 BEQ、BNE
        check_decode(32'h0020C463, 4'd0, 1'b1);

        // JALR 的 opcode 正确，但 funct3 不是 000
        check_decode(32'h00009167, 4'd0, 1'b1);

        // ------------------------------------------------
        // TEST 5：合法与非法切换，检查是否残留旧结果
        // ------------------------------------------------
        $display("TEST 5: valid-invalid transitions");

        check_decode(32'h002081B3, 4'd1, 1'b0);  // ADD
        check_decode(32'h022081B3, 4'd0, 1'b1);  // 不支持 MUL

        check_decode(32'h00308113, 4'd6, 1'b0);  // ADDI
        check_decode(32'h0030E113, 4'd0, 1'b1);  // 不支持 ORI

        check_decode(32'h0040A103, 4'd8, 1'b0);  // LW
        check_decode(32'h00408103, 4'd0, 1'b1);  // 不支持 LB

        check_decode(32'h0020A223, 4'd9, 1'b0);  // SW
        check_decode(32'h00208223, 4'd0, 1'b1);  // 不支持 SB

        check_decode(32'h00208463, 4'd10, 1'b0); // BEQ
        check_decode(32'h0020C463, 4'd0, 1'b1);  // 不支持 BLT

        check_decode(32'h00008167, 4'd13, 1'b0); // JALR
        check_decode(32'h00009167, 4'd0, 1'b1);  // 错误 funct3

        check_decode(32'h123450B7, 4'd7, 1'b0);  // LUI
        check_decode(32'h00000000, 4'd0, 1'b1);  // 非法编码
        check_decode(32'h008000EF, 4'd12, 1'b0); // JAL

        // ------------------------------------------------
        // 最终统计
        // ------------------------------------------------
        if (errors == 0)
            $display(
                "PASS: all decoder tests passed. checks=%0d",
                tests
            );
        else
            $display(
                "FAIL: decoder tests failed. errors=%0d checks=%0d",
                errors, tests
            );

        $stop;
end
    
decoder decoder_inst (
    .inst       (inst),
    .rs1_addr   (rs1_addr),
    .rs2_addr   (rs2_addr),
    .rd_addr    (rd_addr),
    .instr_type (instr_type),
    .illegal    (illegal)
);

endmodule