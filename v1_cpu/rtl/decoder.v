module decoder (
    input  wire [31:0] inst,

    output wire [4:0]  rs1_addr,
    output wire [4:0]  rs2_addr,
    output wire [4:0]  rd_addr,

    output reg  [3:0]  instr_type,
    output reg         illegal
);

// CPU 内部使用的指令类型编码
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

// 从机器码中取出用于识别指令的字段
wire [6:0] opcode;
wire [2:0] funct3;
wire [6:0] funct7;

assign opcode = inst[6:0];
assign funct3 = inst[14:12];
assign funct7 = inst[31:25];

// 提取寄存器地址字段
// 并非每条指令都使用全部三个地址
assign rs1_addr = inst[19:15];
assign rs2_addr = inst[24:20];
assign rd_addr  = inst[11:7];

 // 组合译码
always @(*) 
    begin
        // 默认不支持，避免遗漏赋值产生锁存器
        instr_type = TYPE_INVALID;
        illegal    = 1'b1;

        case (opcode)

            // R 型：两个寄存器之间的运算
            7'b0110011: 
                begin
                    // 拼接 funct7 和 funct3，一起判断
                    case ({funct7, funct3})
                        10'b0000000_000: instr_type = TYPE_ADD;
                        10'b0100000_000: instr_type = TYPE_SUB;
                        10'b0000000_111: instr_type = TYPE_AND;
                        10'b0000000_110: instr_type = TYPE_OR;
                        10'b0000000_100: instr_type = TYPE_XOR;
                        default:        instr_type = TYPE_INVALID;
                    endcase
                end

            // I 型：寄存器加立即数
            7'b0010011:
                begin
                    if (funct3 == 3'b000)
                        instr_type = TYPE_ADDI;
                end

            // U 型：立即数装入高 20 位，低 12 位补零
            7'b0110111: 
                begin
                    instr_type = TYPE_LUI;
                end

            // I 型：读取一个 32 位数据
            7'b0000011: 
                begin
                    if (funct3 == 3'b010)
                        instr_type = TYPE_LW;
                end

            // S 型：写入一个 32 位数据
            7'b0100011: 
                begin
                    if (funct3 == 3'b010)
                        instr_type = TYPE_SW;
                end

            // B 型：条件分支
            7'b1100011: 
                begin
                    case (funct3)
                        3'b000:  instr_type = TYPE_BEQ;
                        3'b001:  instr_type = TYPE_BNE;
                        default: instr_type = TYPE_INVALID;
                    endcase
                end

            // J 型：PC 相对跳转，并保存返回地址
                7'b1101111: 
                begin
                    instr_type = TYPE_JAL;
                end

            // I 型：寄存器间接跳转，并保存返回地址
            7'b1100111: 
                begin
                    if (funct3 == 3'b000)
                        instr_type = TYPE_JALR;
                end

            default: 
                begin
                    instr_type = TYPE_INVALID;
                end
        endcase

        // 成功识别为本项目支持的指令
        if (instr_type != TYPE_INVALID)
            illegal = 1'b0;
    end

endmodule