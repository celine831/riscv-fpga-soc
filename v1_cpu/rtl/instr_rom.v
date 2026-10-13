module instr_rom
(
   /*input wire sys_clk,//如果用同步复位，会导致指令比 PC 晚一拍。
        例如：ROM 输出的是地址 0 的指令；此时 PC 已经变成 4；
    如果遇到 BEQ、JAL，计算跳转地址时就会把错误的 PC 当基地址。*/
    input wire sys_rst_n,
    input wire [31:0] addr,
    output reg [31:0] inst
);

// 空操作：addi x0, x0, 0，不改变通用寄存器的值
localparam [31:0] NOP = 32'h00000013;

always @(*)
begin
    // 复位期间输出NOP
    if (sys_rst_n == 1'b0)
    begin
        inst = NOP;
    end
    else
    begin
        case (addr)

            // addi x1, x0, 10
            // x1 = 10
            32'h0000_0000:
                inst = 32'h00A0_0093;

            // addi x2, x0, 3
            // x2 = 3
            32'h0000_0004:
                inst = 32'h0030_0113;

            // add x3, x1, x2
            // x3 = 10 + 3 = 13
            32'h0000_0008:
                inst = 32'h0020_81B3;

            // sub x4, x1, x2
            // x4 = 10 - 3 = 7
            32'h0000_000C:
                inst = 32'h4020_8233;

            // and x5, x1, x2
            // x5 = 10 & 3 = 2
            32'h0000_0010:
                inst = 32'h0020_F2B3;

            // or x6, x1, x2
            // x6 = 10 | 3 = 11
            32'h0000_0014:
                inst = 32'h0020_E333;

            // xor x7, x1, x2
            // x7 = 10 ^ 3 = 9
            32'h0000_0018:
                inst = 32'h0020_C3B3;

            // lui x8, 0x12345
            // x8 = 0x12345000
            32'h0000_001C:
                inst = 32'h1234_5437;

            // sw x3, 0(x0)
            // RAM地址0写入13
            32'h0000_0020:
                inst = 32'h0030_2023;

            // lw x9, 0(x0)
            // x9读取RAM地址0，结果应为13
            32'h0000_0024:
                inst = 32'h0000_2483;

            // beq x9, x3, +8
            // x9等于x3，跳转到地址48
            32'h0000_0028:
                inst = 32'h0034_8463;

            // addi x10, x0, 1
            // 应该被BEQ跳过，x10应保持0
            32'h0000_002C:
                inst = 32'h0010_0513;

            // bne x1, x2, +8
            // x1不等于x2，跳转到地址56
            32'h0000_0030:
                inst = 32'h0020_9463;

            // addi x11, x0, 1
            // 应该被BNE跳过，x11应保持0
            32'h0000_0034:
                inst = 32'h0010_0593;

            // jal x12, +8
            // 跳转到地址64，x12保存返回地址60
            32'h0000_0038:
                inst = 32'h0080_066F;

            // addi x13, x0, 1
            // 应该被JAL跳过，x13应保持0
            32'h0000_003C:
                inst = 32'h0010_0693;

            // addi x14, x0, 76
            // 为JALR准备跳转目标地址76
            32'h0000_0040:
                inst = 32'h04C0_0713;

            // jalr x15, 0(x14)
            // 跳转到地址76，x15保存返回地址72
            32'h0000_0044:
                inst = 32'h0007_07E7;

            // addi x16, x0, 1
            // 应该被JALR跳过，x16应保持0
            32'h0000_0048:
                inst = 32'h0010_0813;

            // addi x17, x0, 31
            // 程序执行完成标志
            32'h0000_004C:
                inst = 32'h01F0_0893;
            
            // jal x0, 0
            // 程序完成后永久停在地址0x50
            32'h0000_0050:
                inst = 32'h0000_006F;

            // 其他地址执行NOP
            default:
                inst = NOP;

        endcase
    end
end

endmodule