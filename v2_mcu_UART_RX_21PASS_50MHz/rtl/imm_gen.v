module imm_gen
(
    input wire [31:0] inst,
    input wire [3:0] instr_type,
    output reg [31:0] imm
);


  // 必须与 decoder 中的指令类型编码保持一致
localparam [3:0]
    TYPE_ADDI = 4'd6,
    TYPE_LUI  = 4'd7,
    TYPE_LW   = 4'd8,
    TYPE_SW   = 4'd9,
    TYPE_BEQ  = 4'd10,
    TYPE_BNE  = 4'd11,
    TYPE_JAL  = 4'd12,
    TYPE_JALR = 4'd13;

// 组合逻辑：根据指令类型生成立即数
always @(*) 
    begin
        imm = 32'd0;
        
        case (instr_type)
            // I 型：ADDI、LW、JALR
            // 12 位立即数，符号扩展到 32 位
            TYPE_ADDI, TYPE_LW, TYPE_JALR:  imm = {{20{inst[31]}},inst[31:20]};
    
            // U 型：LUI
            // 高 20 位来自指令，低 12 位补零
            TYPE_LUI:   imm = {inst[31:12],12'b0};
    
            // S 型：SW
            // 拼接成 12 位立即数，再符号扩展
            TYPE_SW:  imm = {{20{inst[31]}},inst[31:25],inst[11:7]};
    
            // B 型：BEQ、BNE
            // imm[12|11|10:5|4:1|0]
            // 最低位固定为 0，符号扩展到 32 位
            TYPE_BEQ, TYPE_BNE: imm = {{19{inst[31]}},inst[31],inst[7],inst[30:25],inst[11:8],1'b0};

            // J 型：JAL
            // imm[20|19:12|11|10:1|0]
            // 最低位固定为 0，符号扩展到 32 位
            TYPE_JAL: imm = {{11{inst[31]}},inst[31],inst[19:12],inst[20],inst[30:21],1'b0};
    
            // ADD、SUB、AND、OR、XOR 不需要立即数
            // 无效类型也输出 0
            default:  imm = 32'd0;
        endcase
        
    end

endmodule