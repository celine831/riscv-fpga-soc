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

wire [31:0] rom_inst;
reg  [31:0] inst_reg;
reg         execute;

// inst是锁存后正在执行的指令，FETCH期间可能仍显示上一条指令。
assign inst = inst_reg;

instr_rom u_instr_rom
(
    .sys_rst_n (sys_rst_n),
    .addr      (pc),
    .inst      (rom_inst)
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
// 5. 取指/执行和LW等待状态
// ============================================================
// execute=0：FETCH，PC保持，仅把ROM指令锁存到inst_reg。
// execute=1、load_wait=0：EXECUTE，普通指令提交；LW发起同步读取。
// execute=1、load_wait=1：LOAD_WB，LW写回并更新PC。
// PC只在提交时改变，分支基地址和JAL/JALR返回地址仍对应当前指令。
// 因而普通指令共2拍，LW共3拍；这是多周期CPU，不是流水线。
reg load_wait;

always @(posedge sys_clk or negedge sys_rst_n)
begin
    if (sys_rst_n == 1'b0)
    begin
        inst_reg  <= 32'h0000_0013;
        execute   <= 1'b0;
        load_wait <= 1'b0;
    end
    else if (execute == 1'b0)
    begin
        inst_reg  <= rom_inst;
        execute   <= 1'b1;
        load_wait <= 1'b0;
    end
    else if ((instr_type == TYPE_LW) && (illegal == 1'b0) &&
             (load_wait == 1'b0))
        load_wait <= 1'b1;
    else
    begin
        execute   <= 1'b0;
        load_wait <= 1'b0;
    end
end

// ============================================================
// 6. 寄存器堆和写回信号
// ============================================================
wire [31:0] rs1_data;
wire [31:0] rs2_data;
wire        regfile_wen;

// FETCH阶段禁止写回，防止inst_reg中的上一条指令被重复执行。
// LW仅在LOAD_WB阶段写回，其余指令在EXECUTE阶段写回。
assign regfile_wen = reg_wen && !illegal && execute &&
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

// SW只在EXECUTE提交一次；FETCH期间绝不能重写RAM。
assign data_ram_wen = mem_wen && !illegal && execute;

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
    // FETCH保持PC，把ROM路径和译码/执行路径隔开。
    if (execute == 1'b0)
        pc_next = pc;
    // LW发起读操作时继续保持PC和当前指令。
    else if ((instr_type == TYPE_LW) && (illegal == 1'b0) &&
        (load_wait == 1'b0))
    begin
        pc_next = pc;
    end
    else if (load_wait == 1'b1)
    begin
        // LOAD_WB完成写回后，前往下一条指令。
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
