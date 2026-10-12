module control_unit
(
    input  wire       sys_rst_n,
    input  wire [3:0] instr_type,

    // 寄存器堆写使能
    output reg        reg_wen,

    // 数据存储器写使能
    output reg        mem_wen,

    // ALU的B输入：0选择rs2_data，1选择立即数imm
    output reg        alu_src_imm,

    // ALU运算类型
    output reg  [2:0] alu_op,

    // 寄存器写回数据来源
    output reg  [1:0] wb_sel
);

// 必须与decoder.v、imm_gen.v中的编码一致
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
    TYPE_JALR    = 4'd13;

// 必须与alu.v中的alu_op编码一致
localparam [2:0]
    ALU_ADD = 3'b000,
    ALU_SUB = 3'b001,
    ALU_AND = 3'b010,
    ALU_OR  = 3'b011,
    ALU_XOR = 3'b100;

// 写回来源编码
localparam [1:0]
    WB_ALU = 2'b00,
    WB_MEM = 2'b01,
    WB_IMM = 2'b10,
    WB_PC4 = 2'b11;

always @(*)
begin
    // 默认值：不写寄存器、不写存储器
    reg_wen     = 1'b0;
    mem_wen     = 1'b0;
    alu_src_imm = 1'b0;
    alu_op      = ALU_ADD;
    wb_sel      = WB_ALU;

    // 复位期间禁止所有写操作
    if (sys_rst_n == 1'b1)
    begin
        case (instr_type)

            TYPE_ADD:
            begin
                reg_wen     = 1'b1;
                alu_src_imm = 1'b0;
                alu_op      = ALU_ADD;
                wb_sel      = WB_ALU;
            end

            TYPE_SUB:
            begin
                reg_wen     = 1'b1;
                alu_src_imm = 1'b0;
                alu_op      = ALU_SUB;
                wb_sel      = WB_ALU;
            end

            TYPE_AND:
            begin
                reg_wen     = 1'b1;
                alu_src_imm = 1'b0;
                alu_op      = ALU_AND;
                wb_sel      = WB_ALU;
            end

            TYPE_OR:
            begin
                reg_wen     = 1'b1;
                alu_src_imm = 1'b0;
                alu_op      = ALU_OR;
                wb_sel      = WB_ALU;
            end

            TYPE_XOR:
            begin
                reg_wen     = 1'b1;
                alu_src_imm = 1'b0;
                alu_op      = ALU_XOR;
                wb_sel      = WB_ALU;
            end

            TYPE_ADDI:
            begin
                reg_wen     = 1'b1;
                alu_src_imm = 1'b1;
                alu_op      = ALU_ADD;
                wb_sel      = WB_ALU;
            end

            TYPE_LUI:
            begin
                reg_wen = 1'b1;
                wb_sel  = WB_IMM;
            end

            TYPE_LW:
            begin
                reg_wen     = 1'b1;
                alu_src_imm = 1'b1;
                alu_op      = ALU_ADD;
                wb_sel      = WB_MEM;
            end

            TYPE_SW:
            begin
                mem_wen     = 1'b1;
                alu_src_imm = 1'b1;
                alu_op      = ALU_ADD;
            end

            TYPE_BEQ:
            begin
                // rs1-rs2，结果为0表示相等
                alu_src_imm = 1'b0;
                alu_op      = ALU_SUB;
            end

            TYPE_BNE:
            begin
                alu_src_imm = 1'b0;
                alu_op      = ALU_SUB;
            end

            TYPE_JAL:
            begin
                reg_wen = 1'b1;
                wb_sel  = WB_PC4;
            end

            TYPE_JALR:
            begin
                reg_wen     = 1'b1;
                alu_src_imm = 1'b1;
                alu_op      = ALU_ADD;
                wb_sel      = WB_PC4;
            end

            // 非法指令不产生任何写操作
            default:
            begin
                reg_wen     = 1'b0;
                mem_wen     = 1'b0;
                alu_src_imm = 1'b0;
                alu_op      = ALU_ADD;
                wb_sel      = WB_ALU;
            end

        endcase
    end
end

endmodule