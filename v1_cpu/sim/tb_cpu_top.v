`timescale 1ns/1ps

module tb_cpu_top;

reg         sys_clk;
reg         sys_rst_n;
wire [31:0] pc;
wire [31:0] inst;
wire [31:0] alu_result;
wire [31:0] wb_data;

integer checks;
integer errors;

cpu_top dut
(
    .sys_clk    (sys_clk),
    .sys_rst_n  (sys_rst_n),
    .pc         (pc),
    .inst       (inst),
    .alu_result (alu_result),
    .wb_data    (wb_data)
);

initial
begin
    sys_clk = 1'b0;
    forever #10 sys_clk = ~sys_clk;
end

task check32;
    input [8*80-1:0] name;
    input [31:0] actual;
    input [31:0] expected;
    begin
        checks = checks + 1;
        if (actual === expected)
            $display("[PASS] %0s: actual=%h", name, actual);
        else
        begin
            errors = errors + 1;
            $display("[FAIL] %0s: actual=%h expected=%h",
                     name, actual, expected);
        end
    end
endtask

task next_clock;
    begin
        @(posedge sys_clk);
        #1;
    end
endtask

// 每条普通指令先FETCH，再EXECUTE。FETCH时不允许提交上一条指令。
task execute_instruction;
    reg [31:0] saved_pc;
    begin
        saved_pc = pc;
        check32("FETCH phase disables register writes", {31'd0, dut.regfile_wen}, 32'd0);
        check32("FETCH phase disables RAM writes", {31'd0, dut.data_ram_wen}, 32'd0);
        next_clock;
        check32("FETCH holds PC", pc, saved_pc);
        next_clock;
    end
endtask

initial
begin
    checks    = 0;
    errors    = 0;
    sys_rst_n = 1'b1;

    #2;
    sys_rst_n = 1'b0;
    #1;
    $display("\nTEST 1: asynchronous reset");
    check32("PC is zero", pc, 32'h0000_0000);
    check32("instruction register resets to NOP", inst, 32'h0000_0013);
    check32("x1 is zero", dut.regsfile_inst.regs[1], 32'd0);

    @(negedge sys_clk);
    sys_rst_n = 1'b1;
    #1;

    $display("\nTEST 2: arithmetic and logic instructions");
    execute_instruction;
    check32("ADDI x1", dut.regsfile_inst.regs[1], 32'd10);
    execute_instruction;
    check32("ADDI x2", dut.regsfile_inst.regs[2], 32'd3);
    execute_instruction;
    check32("ADD x3", dut.regsfile_inst.regs[3], 32'd13);
    execute_instruction;
    check32("SUB x4", dut.regsfile_inst.regs[4], 32'd7);
    execute_instruction;
    check32("AND x5", dut.regsfile_inst.regs[5], 32'd2);
    execute_instruction;
    check32("OR x6", dut.regsfile_inst.regs[6], 32'd11);
    execute_instruction;
    check32("XOR x7", dut.regsfile_inst.regs[7], 32'd9);
    execute_instruction;
    check32("LUI x8", dut.regsfile_inst.regs[8], 32'h1234_5000);

    $display("\nTEST 3: SW and three-cycle LW");
    execute_instruction;
    check32("SW advances PC to 36", pc, 32'h0000_0024);
    check32("SW stores 13", dut.data_ram_inst.mem[0], 32'd13);

    // LW第一拍：只锁存指令，PC和目标寄存器保持不变。
    check32("FETCH after SW cannot repeat RAM write", {31'd0, dut.data_ram_wen}, 32'd0);
    next_clock;
    check32("LW FETCH holds PC", pc, 32'h0000_0024);
    check32("LW FETCH does not write x9",
            dut.regsfile_inst.regs[9], 32'd0);

    // LW第二拍：发起同步读取，尚不能写回。
    next_clock;
    check32("LW EXECUTE holds PC", pc, 32'h0000_0024);
    check32("LW EXECUTE does not write x9", dut.regsfile_inst.regs[9], 32'd0);

    // LW第三拍：写回同步RAM输出，PC前进。
    next_clock;
    check32("LW LOAD_WB advances PC", pc, 32'h0000_0028);
    check32("LW writes 13 into x9", dut.regsfile_inst.regs[9], 32'd13);

    $display("\nTEST 4: branches and jumps");
    execute_instruction;
    check32("BEQ jumps to 48", pc, 32'h0000_0030);
    check32("x10 is skipped", dut.regsfile_inst.regs[10], 32'd0);
    execute_instruction;
    check32("BNE jumps to 56", pc, 32'h0000_0038);
    check32("x11 is skipped", dut.regsfile_inst.regs[11], 32'd0);
    execute_instruction;
    check32("JAL jumps to 64", pc, 32'h0000_0040);
    check32("JAL return address", dut.regsfile_inst.regs[12], 32'h0000_003C);
    execute_instruction;
    check32("x14 contains JALR target", dut.regsfile_inst.regs[14],
            32'h0000_004C);
    execute_instruction;
    check32("JALR jumps to 76", pc, 32'h0000_004C);
    check32("JALR return address", dut.regsfile_inst.regs[15],
            32'h0000_0048);
    check32("x16 is skipped", dut.regsfile_inst.regs[16], 32'd0);
    execute_instruction;
    check32("program completion value", dut.regsfile_inst.regs[17], 32'd31);
    check32("PC advances to 80", pc, 32'h0000_0050);

    $display("\nTEST 5: completion loop");
    execute_instruction;
    execute_instruction;
    check32("JAL x0,0 holds completion PC", pc, 32'h0000_0050);
    check32("x0 remains zero", dut.regsfile_inst.regs[0], 32'd0);

    $display("\nTEST 6: reset after execution");
    #2;
    sys_rst_n = 1'b0;
    #1;
    check32("PC returns to zero", pc, 32'd0);
    check32("x17 is cleared", dut.regsfile_inst.regs[17], 32'd0);
    check32("RAM output is masked to zero", dut.mem_rdata, 32'd0);
    // 注意：M9K内部内容不会被复位清空，因此这里不检查mem[0]==0。

    $display("\n========================================");
    if (errors == 0)
        $display("tb_cpu_top PASS: checks=%0d", checks);
    else
        $display("tb_cpu_top FAIL: checks=%0d errors=%0d", checks, errors);
    $display("========================================\n");
    $stop;
end

endmodule
