module cpu_top
(
    input  wire        sys_clk,
    input  wire        sys_rst_n,

    // 直接引出CPU内部关键信号，便于整机仿真和后续上板观察
    output wire [31:0] pc,
    output wire [31:0] inst,
    output wire [31:0] alu_result,
    output reg  [31:0] wb_data
);

// 必须与decoder.v、imm_gen.v和control_unit.v中的指令类型编码一致
localparam [3:0]
    TYPE_LW   = 4'd8,
    TYPE_BEQ  = 4'd10,
    TYPE_BNE  = 4'd11,
    TYPE_JAL  = 4'd12,
    TYPE_JALR = 4'd13;

// 必须与control_unit.v中的写回来源编码一致
localparam [1:0]
    WB_ALU = 2'b00,
    WB_MEM = 2'b01,
    WB_IMM = 2'b10,
    WB_PC4 = 2'b11;

// ============================================================
// 1. PC和取指信号
// ============================================================
reg  [31:0] pc_next;
wire [31:0] pc_plus4;

assign pc_plus4 = pc + 32'd4;

pc_reg pc_reg_inst
(
    .sys_clk   (sys_clk),
    .sys_rst_n (sys_rst_n),
    .pc_next   (pc_next),
    .pc        (pc)
);

instr_rom u_instr_rom
(
    .sys_rst_n (sys_rst_n),
    .addr      (pc),
    .inst      (inst)
);

// ============================================================
// 2. 指令译码
// ============================================================
wire [4:0] rs1_addr;
wire [4:0] rs2_addr;
wire [4:0] rd_addr;
wire [3:0] instr_type;
wire       illegal;

decoder decoder_inst
(
    .inst       (inst),
    .rs1_addr   (rs1_addr),
    .rs2_addr   (rs2_addr),
    .rd_addr    (rd_addr),
    .instr_type (instr_type),
    .illegal    (illegal)
);

// ============================================================
// 3. 立即数生成
// ============================================================
wire [31:0] imm;

imm_gen u_imm_gen
(
    .inst       (inst),
    .instr_type (instr_type),
    .imm        (imm)
);

// ============================================================
// 4. 控制器
// ============================================================
wire       reg_wen;
wire       mem_wen;
wire       alu_src_imm;
wire [2:0] alu_op;
wire [1:0] wb_sel;

control_unit control_unit_inst
(
    .sys_rst_n   (sys_rst_n),
    .instr_type  (instr_type),
    .reg_wen     (reg_wen),
    .mem_wen     (mem_wen),
    .alu_src_imm (alu_src_imm),
    .alu_op      (alu_op),
    .wb_sel      (wb_sel)
);

// ============================================================
// 5. LW等待状态
// ============================================================
// load_wait=0：LW第一拍，保持PC并向RAM发出读地址；
// load_wait=1：LW第二拍，把RAM数据写回rd，然后PC前进。
reg load_wait;

always @(posedge sys_clk or negedge sys_rst_n)
begin
    if (sys_rst_n == 1'b0)
        load_wait <= 1'b0;
    else if (load_wait == 1'b1)
        load_wait <= 1'b0;
    else if ((instr_type == TYPE_LW) && (illegal == 1'b0))
        load_wait <= 1'b1;
end

// ============================================================
// 6. 寄存器堆和写回信号
// ============================================================
wire [31:0] rs1_data;
wire [31:0] rs2_data;
wire        regfile_wen;

// 普通指令照常写回；LW只允许在第二拍(load_wait=1)写回。
assign regfile_wen = reg_wen && !illegal &&
                     ((instr_type != TYPE_LW) || load_wait);

regsfile regsfile_inst
(
    .sys_clk   (sys_clk),
    .sys_rst_n (sys_rst_n),
    .wen       (regfile_wen),
    .waddr     (rd_addr),
    .wdata     (wb_data),
    .raddr1    (rs1_addr),
    .raddr2    (rs2_addr),
    .rdata1    (rs1_data),
    .rdata2    (rs2_data)
);

// ============================================================
// 7. ALU输入选择和运算
// ============================================================
wire [31:0] alu_b;

assign alu_b = (alu_src_imm == 1'b1) ? imm : rs2_data;

alu alu_inst
(
    .a      (rs1_data),
    .b      (alu_b),
    .alu_op (alu_op),
    .result (alu_result)
);

// ============================================================
// 8. 数据RAM
// ============================================================
wire [31:0] mem_rdata;
wire        data_ram_wen;

assign data_ram_wen = mem_wen && !illegal;

data_ram
#(
    .ADDR_WIDTH (8)
)
data_ram_inst
(
    .sys_clk   (sys_clk),
    .sys_rst_n (sys_rst_n),
    .wen       (data_ram_wen),
    .addr      (alu_result),
    .wdata     (rs2_data),
    .rdata     (mem_rdata)
);

// ============================================================
// 9. 写回数据选择
// ============================================================
always @(*)
begin
    case (wb_sel)
        WB_ALU: wb_data = alu_result;
        WB_MEM: wb_data = mem_rdata;
        WB_IMM: wb_data = imm;
        WB_PC4: wb_data = pc_plus4;
        default: wb_data = 32'd0;
    endcase
end

// ============================================================
// 10. 下一条PC选择
// ============================================================
wire        equal;
wire        branch_taken;
wire        is_jal;
wire        is_jalr;
wire [1:0]  next_pc_sel;
wire [31:0] pc_imm;
wire [31:0] jalr_target;

assign equal = (rs1_data == rs2_data);
assign branch_taken = ((instr_type == TYPE_BEQ) &&  equal) ||
                      ((instr_type == TYPE_BNE) && !equal);

assign is_jal      = (instr_type == TYPE_JAL);
assign is_jalr     = (instr_type == TYPE_JALR);
assign next_pc_sel = {is_jalr, (is_jal || branch_taken)};

assign pc_imm      = pc + imm;
assign jalr_target = alu_result & 32'hFFFF_FFFE;

always @(*)
begin
    // LW第一拍保持PC，使译码结果、rd和RAM地址保持不变。
    if ((instr_type == TYPE_LW) && (illegal == 1'b0) &&
        (load_wait == 1'b0))
    begin
        pc_next = pc;
    end
    else if (load_wait == 1'b1)
    begin
        // LW第二拍完成写回后，前往下一条指令。
        pc_next = pc_plus4;
    end
    else
    begin
        case (next_pc_sel)
            2'b00:   pc_next = pc_plus4;
            2'b01:   pc_next = pc_imm;
            2'b10:   pc_next = jalr_target;
            default: pc_next = pc_plus4;
        endcase
    end
end

endmodule
