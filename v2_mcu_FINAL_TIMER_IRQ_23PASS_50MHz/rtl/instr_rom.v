module instr_rom
#(parameter PROGRAM = 0,
  parameter [31:0] TIMER_DEMO_PERIOD = 32'd25_000_000)
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
// RISC-V LUI+ADDI使用带符号的12位ADDI立即数。
localparam [31:0] TIMER_HI = (TIMER_DEMO_PERIOD + 32'h0000_0800)
                            & 32'hFFFF_F000;
localparam [31:0] TIMER_LO = TIMER_DEMO_PERIOD - TIMER_HI;

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
            // PROGRAM=0停在0x50；PROGRAM=1从此处继续GPIO测试程序
            32'h0000_0050:
                inst = (PROGRAM == 0) ? 32'h0000_006F : 32'h1000_0937;

            // addi x19,x0,5
            32'h00000054: inst = (PROGRAM != 0) ? 32'h00500993 : NOP;

            // sw x19,0(x18) : GPIO=5
            32'h00000058: inst = (PROGRAM != 0) ? 32'h01392023 : NOP;

            // lw x20,0(x18) : read output=5
            32'h0000005C: inst = (PROGRAM != 0) ? 32'h00092A03 : NOP;

            // lw x21,4(x18) : read external input
            32'h00000060: inst = (PROGRAM != 0) ? 32'h00492A83 : NOP;

            // addi x19,x0,426 : 0x1AA
            32'h00000064: inst = (PROGRAM != 0) ? 32'h1AA00993 : NOP;

            // sw x19,0(x18) : low eight bits=0xAA
            32'h00000068: inst = (PROGRAM != 0) ? 32'h01392023 : NOP;

            // lw x22,0(x18) : read output=0xAA
            32'h0000006C: inst = (PROGRAM != 0) ? 32'h00092B03 : NOP;

            // lw x23,8(x18) : invalid GPIO offset returns zero
            32'h00000070: inst = (PROGRAM != 0) ? 32'h00892B83 : NOP;

            // sw x19,1(x18) : unaligned write ignored
            32'h00000074: inst = (PROGRAM != 0) ? 32'h013920A3 : NOP;

            // sw x19,4(x18) : input register is read-only
            32'h00000078: inst = (PROGRAM != 0) ? 32'h01392223 : NOP;

            // lw x24,0(x18) : output remains 0xAA
            32'h0000007C: inst = (PROGRAM != 0) ? 32'h00092C03 : NOP;

            // lw x25,0(x0) : RAM still contains 13
            32'h00000080: inst = (PROGRAM != 0) ? 32'h00002C83 : NOP;

            // sw x19,8(x18) : invalid offset write ignored
            32'h00000084: inst = (PROGRAM != 0) ? 32'h01392423 : NOP;

            // lw x26,1(x18) : unaligned read returns zero
            32'h00000088: inst = (PROGRAM != 0) ? 32'h00192D03 : NOP;

            // lui x27,0x20000 : unmapped region
            32'h0000008C: inst = (PROGRAM != 0) ? 32'h20000DB7 : NOP;

            // sw x19,0(x27) : unmapped write ignored
            32'h00000090: inst = (PROGRAM != 0) ? 32'h013DA023 : NOP;

            // lw x28,0(x27) : unmapped read returns zero
            32'h00000094: inst = (PROGRAM != 0) ? 32'h000DAE03 : NOP;

            // addi x19,x0,1
            32'h00000098: inst = (PROGRAM != 0) ? 32'h00100993 : NOP;

            // sw x19,0(x18) : final GPIO output=1
            32'h0000009C: inst = (PROGRAM != 0) ? 32'h01392023 : NOP;

            // lw x29,0(x18) : read final output=1
            32'h000000A0: inst = (PROGRAM != 0) ? 32'h00092E83 : NOP;

            // lw x30,0(x0) : RAM remains 13
            32'h000000A4: inst = (PROGRAM != 0) ? 32'h00002F03 : NOP;

            // PROGRAM=1停止；PROGRAM=2/3继续Timer程序。
            32'h000000A8: inst = (PROGRAM >= 2) ? 32'h00000993 :
                                (PROGRAM == 1) ? 32'h0000006F : NOP;

            // PROGRAM=2/3: GPIO先灭，Timer到期后再点亮。
            32'h000000AC: inst = (PROGRAM >= 2) ? 32'h01392023 : NOP; // sw x19,0(x18)
            32'h000000B0: inst = (PROGRAM >= 2) ? 32'h100010B7 : NOP; // lui x1,0x10001
            32'h000000B4: inst = (PROGRAM >= 2) ?
                                {TIMER_HI[31:12],5'd2,7'h37} : NOP; // lui x2,hi
            32'h000000B8: inst = (PROGRAM >= 2) ?
                                {TIMER_LO[11:0],5'd2,3'b000,5'd2,7'h13} : NOP;
            32'h000000BC: inst = (PROGRAM >= 2) ? 32'h0020A223 : NOP; // sw x2,4(x1)
            32'h000000C0: inst = (PROGRAM >= 2) ? 32'h00100193 : NOP; // addi x3,x0,1
            32'h000000C4: inst = (PROGRAM >= 2) ? 32'h0030A023 : NOP; // sw x3,0(x1)
            32'h000000C8: inst = (PROGRAM >= 2) ? 32'h00C0A203 : NOP; // lw x4,12(x1)
            32'h000000CC: inst = (PROGRAM >= 2) ? 32'hFE020EE3 : NOP; // beq x4,x0,-4
            32'h000000D0: inst = (PROGRAM >= 2) ? 32'h00100993 : NOP; // addi x19,x0,1
            32'h000000D4: inst = (PROGRAM >= 2) ? 32'h01392023 : NOP; // sw x19,0(x18)
            32'h000000D8: inst = (PROGRAM >= 3) ? 32'h10002337 :
                                (PROGRAM == 2) ? 32'h0000006F : NOP; // lui x6,0x10002
            // PROGRAM=3/4: 等待UART空闲后发送ASCII "OK\n"。
            32'h000000DC: inst = (PROGRAM >= 3) ? 32'h00432203 : NOP; // lw x4,4(x6)
            32'h000000E0: inst = (PROGRAM >= 3) ? 32'hFE021EE3 : NOP; // bne x4,x0,-4
            32'h000000E4: inst = (PROGRAM >= 3) ? 32'h04F00293 : NOP; // addi x5,x0,'O'
            32'h000000E8: inst = (PROGRAM >= 3) ? 32'h00532023 : NOP; // sw x5,0(x6)
            32'h000000EC: inst = (PROGRAM >= 3) ? 32'h00432203 : NOP;
            32'h000000F0: inst = (PROGRAM >= 3) ? 32'hFE021EE3 : NOP;
            32'h000000F4: inst = (PROGRAM >= 3) ? 32'h04B00293 : NOP; // addi x5,x0,'K'
            32'h000000F8: inst = (PROGRAM >= 3) ? 32'h00532023 : NOP;
            32'h000000FC: inst = (PROGRAM >= 3) ? 32'h00432203 : NOP;
            32'h00000100: inst = (PROGRAM >= 3) ? 32'hFE021EE3 : NOP;
            32'h00000104: inst = (PROGRAM >= 3) ? 32'h00A00293 : NOP; // addi x5,x0,LF
            32'h00000108: inst = (PROGRAM >= 3) ? 32'h00532023 : NOP;
            32'h0000010C: inst = (PROGRAM >= 3) ? 32'h00432203 : NOP;
            32'h00000110: inst = (PROGRAM >= 3) ? 32'hFE021EE3 : NOP;
            32'h00000114: inst = (PROGRAM == 5) ? 32'h03C0006F :
                                (PROGRAM == 4) ? 32'h100033B7 :
                                (PROGRAM == 3) ? 32'h0000006F : NOP; // lui x7,0x10003
            // PROGRAM=4: 接收'0'/'1'控制GPIO，其它字符忽略。
            32'h00000118: inst = (PROGRAM >= 4) ? 32'h0043A403 : NOP; // lw x8,4(x7)
            32'h0000011C: inst = (PROGRAM >= 4) ? 32'hFE040EE3 : NOP; // beq x8,x0,-4
            32'h00000120: inst = (PROGRAM >= 4) ? 32'h0003A483 : NOP; // lw x9,0(x7)
            32'h00000124: inst = (PROGRAM >= 4) ? 32'h03000513 : NOP; // addi x10,x0,'0'
            32'h00000128: inst = (PROGRAM >= 4) ? 32'h00A49663 : NOP; // bne x9,x10,+12
            32'h0000012C: inst = (PROGRAM >= 4) ? 32'h00000993 : NOP; // addi x19,x0,0
            32'h00000130: inst = (PROGRAM >= 4) ? 32'h0100006F : NOP; // jal x0,+16
            32'h00000134: inst = (PROGRAM >= 4) ? 32'h03100513 : NOP; // addi x10,x0,'1'
            32'h00000138: inst = (PROGRAM >= 4) ? 32'h00A49663 : NOP; // bne x9,x10,+12
            32'h0000013C: inst = (PROGRAM >= 4) ? 32'h00100993 : NOP; // addi x19,x0,1
            32'h00000140: inst = (PROGRAM >= 4) ? 32'h01392023 : NOP; // sw x19,0(x18)
            32'h00000144: inst = (PROGRAM >= 4) ? 32'h00100593 : NOP; // addi x11,x0,1
            32'h00000148: inst = (PROGRAM >= 4) ? 32'h00B3A223 : NOP; // sw x11,4(x7) clear valid
            32'h0000014C: inst = (PROGRAM >= 4) ? 32'hFCDFF06F : NOP; // jal x0,-52

            // PROGRAM=5: 配置本地Timer中断，再进入原UART RX命令循环。
            32'h00000150: inst = (PROGRAM == 5) ? 32'h100033B7 : NOP; // lui x7,0x10003
            32'h00000154: inst = (PROGRAM == 5) ? 32'h00100B13 : NOP; // addi x22,x0,1
            32'h00000158: inst = (PROGRAM == 5) ? 32'h0160A623 : NOP; // 清除旧Timer STATUS
            32'h0000015C: inst = (PROGRAM == 5) ? 32'h20000B93 : NOP; // handler=0x200
            32'h00000160: inst = (PROGRAM == 5) ? 32'h305B9073 : NOP; // csrrw x0,mtvec,x23
            32'h00000164: inst = (PROGRAM == 5) ? 32'h00010BB7 : NOP; // x23=bit16
            32'h00000168: inst = (PROGRAM == 5) ? 32'h304B9073 : NOP; // csrrw x0,mie,x23
            32'h0000016C: inst = (PROGRAM == 5) ? 32'h00800B93 : NOP; // x23=bit3
            32'h00000170: inst = (PROGRAM == 5) ? 32'h300B9073 : NOP; // csrrw x0,mstatus,x23
            32'h00000174: inst = (PROGRAM == 5) ? 32'h0020A223 : NOP; // load timer period
            32'h00000178: inst = (PROGRAM == 5) ? 32'h00300B93 : NOP; // periodic+enable
            32'h0000017C: inst = (PROGRAM == 5) ? 32'h0170A023 : NOP; // start periodic timer
            32'h00000180: inst = (PROGRAM == 5) ? 32'hF99FF06F : NOP; // jal x0,0x118

            // Local interrupt handler: toggle GPIO, clear Timer, return.
            32'h00000200: inst = (PROGRAM == 5) ? 32'h0169C9B3 : NOP; // xor x19,x19,x22
            32'h00000204: inst = (PROGRAM == 5) ? 32'h01392023 : NOP; // sw x19,0(x18)
            32'h00000208: inst = (PROGRAM == 5) ? 32'h0160A623 : NOP; // sw x22,12(x1)
            32'h0000020C: inst = (PROGRAM == 5) ? 32'h30200073 : NOP; // mret

            // 其他地址执行NOP
            default:
                inst = NOP;

        endcase
    end
end

endmodule
