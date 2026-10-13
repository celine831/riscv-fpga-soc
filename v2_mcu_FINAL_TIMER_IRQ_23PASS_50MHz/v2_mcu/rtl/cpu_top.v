module cpu_top
#(
    parameter ROM_PROGRAM = 0,
    parameter [31:0] TIMER_DEMO_PERIOD = 32'd25_000_000,
    parameter integer UART_CLKS_PER_BIT = 434
)
(
    input  wire        sys_clk,
    input  wire        sys_rst_n,

    // 直接引出CPU内部关键信号，便于整机仿真和后续上板观察
    output wire [31:0] pc,
    output wire [31:0] inst,
    output wire [31:0] alu_result,
    output reg  [31:0] wb_data,
    input  wire [7:0] gpio_in,
    output wire [7:0] gpio_out,
    output wire       uart_tx_pin,
    input  wire       uart_rx_pin
);

// 必须与decoder.v、imm_gen.v和control_unit.v中的指令类型编码一致
localparam [3:0]
    TYPE_LW   = 4'd8,
    TYPE_BEQ  = 4'd10,
    TYPE_BNE  = 4'd11,
    TYPE_JAL  = 4'd12,
    TYPE_JALR = 4'd13,
    TYPE_CSR  = 4'd14,
    TYPE_MRET = 4'd15;

// 必须与control_unit.v中的写回来源编码一致
localparam [1:0]
    WB_ALU = 2'b00,
    WB_MEM = 2'b01,
    WB_IMM = 2'b10,
    WB_PC4 = 2'b11;

// Declare interrupt/CSR signals before their first use. ModelSim 10.5
// otherwise creates implicit nets and then rejects later declarations.
wire timer_irq;
wire irq_request;
wire take_irq;
wire [31:0] mtvec;
wire [31:0] mepc;
wire [31:0] mcause;
wire [31:0] csr_rdata;
wire [31:0] csr_wdata;
wire csr_write;
wire do_mret;

// ============================================================
// 1. PC和取指信号
// ============================================================
reg  [31:0] pc_next;
wire [31:0] pc_d;
wire [31:0] pc_plus4;

// FETCH: ROM组合输出只进入指令寄存器。
// EXEC: 仅在下一拍更新CPU架构状态，切断PC->ROM->译码->写入端的长路径。
reg  [31:0] inst_reg;
wire [31:0] rom_inst;
reg         exec_phase;
assign inst = inst_reg;

always @(posedge sys_clk or negedge sys_rst_n)
    if (sys_rst_n == 1'b0)
    begin
        inst_reg   <= 32'h0000_0013;
        exec_phase <= 1'b0;
    end
    else
    begin
        exec_phase <= ~exec_phase;
        if (exec_phase == 1'b0)
            inst_reg <= rom_inst;
    end

assign pc_plus4 = pc + 32'd4;

pc_reg pc_reg_inst
(
    .sys_clk   (sys_clk),
    .sys_rst_n (sys_rst_n),
    .pc_next   (pc_d),
    .pc        (pc)
);

instr_rom #(
    .PROGRAM(ROM_PROGRAM),
    .TIMER_DEMO_PERIOD(TIMER_DEMO_PERIOD)
) u_instr_rom
(
    .sys_rst_n (sys_rst_n),
    .addr      (pc),
    .inst      (rom_inst)
);
assign pc_d = exec_phase ? (take_irq ? mtvec : pc_next) : pc;

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
    else if (exec_phase == 1'b1)
        if (load_wait == 1'b1)
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
assign regfile_wen = exec_phase && reg_wen && !illegal && !take_irq &&
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
// 8. RAM与GPIO的内存映射访问
// RAM: 0x00000000~0x000003FF；GPIO: 0x10000000~0x10000FFF；
// Timer: 0x10001000~0x10001FFF；UART TX: 0x10002000~0x10002FFF；
// UART RX: 0x10003000~0x10003FFF。
// 模块内部核对精确寄存器地址。
// ============================================================
wire [31:0] mem_rdata;
wire [31:0] ram_rdata;
wire [31:0] gpio_rdata;
wire [31:0] timer_rdata;
wire [31:0] uart_rdata;
wire [31:0] uart_rx_rdata;
wire        ram_sel;
wire        gpio_sel;
wire        timer_sel;
wire        uart_sel;
wire        uart_rx_sel;
wire        data_ram_wen;
wire        load_req;
reg  [2:0]  load_target;
reg  [31:0] load_addr;
reg         timer_write_pending;
reg  [31:0] timer_write_addr;
reg  [31:0] timer_write_data;
wire        timer_write_req;
reg         uart_write_pending;
reg  [31:0] uart_write_addr;
reg  [31:0] uart_write_data;
wire        uart_write_req;

assign ram_sel = (alu_result[31:10] == 22'd0) &&
                 (alu_result[1:0] == 2'b00);
assign gpio_sel = (alu_result[31:12] == 20'h10000);
assign timer_sel = (alu_result[31:12] == 20'h10001);
assign uart_sel = (alu_result[31:12] == 20'h10002);
assign uart_rx_sel = (alu_result[31:12] == 20'h10003);
assign data_ram_wen = exec_phase && mem_wen && !illegal && !take_irq && ram_sel && sys_rst_n;
assign load_req = exec_phase && (instr_type == TYPE_LW) && !illegal &&
                  !load_wait && !take_irq && sys_rst_n;
assign timer_write_req = exec_phase && mem_wen && !illegal && !take_irq &&
                         timer_sel && sys_rst_n;
assign uart_write_req = exec_phase && mem_wen && !illegal && !take_irq &&
                        uart_sel && sys_rst_n;

// Timer 写命令先在 EXEC 沿锁存，再在下一 FETCH 沿提交。
// 从指令寄存器经寄存器堆、ALU、地址译码到计数器的长路径到此为止。
// 后续指令最早在再下一 EXEC 沿执行，仍能看到已提交的 Timer 写入。
always @(posedge sys_clk or negedge sys_rst_n)
    if (sys_rst_n == 1'b0)
    begin
        timer_write_pending <= 1'b0;
        timer_write_addr    <= 32'd0;
        timer_write_data    <= 32'd0;
    end
    else
    begin
        timer_write_pending <= timer_write_req;
        if (timer_write_req)
        begin
            timer_write_addr <= alu_result;
            timer_write_data <= rs2_data;
        end
    end

// UART TX 写命令在下一 FETCH 沿提交，切断译码到串口帧寄存器的路径。
always @(posedge sys_clk or negedge sys_rst_n)
    if (sys_rst_n == 1'b0)
    begin
        uart_write_pending <= 1'b0;
        uart_write_addr    <= 32'd0;
        uart_write_data    <= 32'd0;
    end
    else
    begin
        uart_write_pending <= uart_write_req;
        if (uart_write_req)
        begin
            uart_write_addr <= alu_result;
            uart_write_data <= rs2_data;
        end
    end

// 保存第一拍选中的读目标，与同步返回的数据对齐。
// 0=RAM，1=GPIO，2=无效地址，3=Timer，4=UART TX，5=UART RX。
always @(posedge sys_clk or negedge sys_rst_n)
    if (sys_rst_n == 1'b0)
        load_target <= 3'd2;
    else if (load_req)
        if (ram_sel)
            load_target <= 3'd0;
        else if (gpio_sel)
            load_target <= 3'd1;
        else if (timer_sel)
            load_target <= 3'd3;
        else if (uart_sel)
            load_target <= 3'd4;
        else if (uart_rx_sel)
            load_target <= 3'd5;
        else
            load_target <= 3'd2;

always @(posedge sys_clk or negedge sys_rst_n)
    if (sys_rst_n == 1'b0)
        load_addr <= 32'd0;
    else if (load_req)
        load_addr <= alu_result;

data_ram #(.ADDR_WIDTH(8)) data_ram_inst
(
    .sys_clk(sys_clk),
    .sys_rst_n(sys_rst_n),
    .wen(data_ram_wen),
    .addr(alu_result),
    .wdata(rs2_data),
    .rdata(ram_rdata)
);

gpio gpio_inst
(
    .sys_clk(sys_clk),
    .sys_rst_n(sys_rst_n),
    .sel(gpio_sel),
    .wen(exec_phase && mem_wen && !illegal && !take_irq),
    // LW等待期间的FETCH沿刷新同步读结果，供下一EXEC沿写回。
    .ren(load_req || (!exec_phase && load_wait)),
    .addr(alu_result),
    .wdata(rs2_data),
    .gpio_in(gpio_in),
    .gpio_out(gpio_out),
    .rdata(gpio_rdata)
);

timer timer_inst
(
    .sys_clk(sys_clk),
    .sys_rst_n(sys_rst_n),
    .sel(timer_write_pending),
    .wen(timer_write_pending),
    .ren(!exec_phase && load_wait),
    .addr(timer_write_addr),
    .wdata(timer_write_data),
    .read_sel(load_target == 3'd3),
    .read_addr(load_addr),
    .rdata(timer_rdata),
    .irq(timer_irq)
);

uart_tx #(.CLKS_PER_BIT(UART_CLKS_PER_BIT)) uart_inst
(
    .sys_clk(sys_clk),
    .sys_rst_n(sys_rst_n),
    .sel(uart_write_pending),
    .wen(uart_write_pending),
    .ren(!exec_phase && load_wait),
    .addr(uart_write_addr),
    .wdata(uart_write_data),
    .read_sel(load_target == 3'd4),
    .read_addr(load_addr),
    .rdata(uart_rdata),
    .tx(uart_tx_pin)
);

uart_rx #(.CLKS_PER_BIT(UART_CLKS_PER_BIT)) uart_rx_inst
(
    .sys_clk(sys_clk),
    .sys_rst_n(sys_rst_n),
    .rx_pin(uart_rx_pin),
    .sel(uart_rx_sel),
    .wen(exec_phase && mem_wen && !illegal && !take_irq),
    .ren(load_req || (!exec_phase && load_wait)),
    .addr(alu_result),
    .wdata(rs2_data),
    .rdata(uart_rx_rdata)
);

assign mem_rdata = !sys_rst_n ? 32'd0 :
                  (load_target == 3'd0) ? ram_rdata :
                  (load_target == 3'd1) ? gpio_rdata :
                  (load_target == 3'd3) ? timer_rdata :
                  (load_target == 3'd4) ? uart_rdata :
                  (load_target == 3'd5) ? uart_rx_rdata : 32'd0;

// ============================================================
// 9. 写回数据选择
// ============================================================
always @(*)
begin
    case (wb_sel)
        WB_ALU: wb_data = (instr_type == TYPE_CSR) ? csr_rdata : alu_result;
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

// Interrupts are sampled only before an instruction executes. A pending LW
// completes its second EXEC before interrupt entry, preserving precise mepc.
assign take_irq = exec_phase && !load_wait && irq_request && sys_rst_n;
assign do_mret = exec_phase && !take_irq && !illegal &&
                 (instr_type == TYPE_MRET);
assign csr_write = exec_phase && !take_irq && !illegal &&
                   (instr_type == TYPE_CSR) &&
                   ((inst[14:12] == 3'b001) || (rs1_addr != 5'd0));
assign csr_wdata = (inst[14:12] == 3'b010) ?
                   (csr_rdata | rs1_data) : rs1_data;

irq_csrs irq_csrs_inst
(
    .sys_clk(sys_clk), .sys_rst_n(sys_rst_n),
    .csr_addr(inst[31:20]), .csr_wdata(csr_wdata),
    .csr_write(csr_write), .trap(take_irq), .trap_pc(pc),
    .mret(do_mret), .timer_irq(timer_irq),
    .csr_rdata(csr_rdata), .irq_request(irq_request),
    .mtvec(mtvec), .mepc(mepc), .mcause(mcause)
);

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
    if (do_mret)
    begin
        pc_next = mepc;
    end
    else if ((instr_type == TYPE_LW) && (illegal == 1'b0) &&
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
