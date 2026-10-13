`timescale 1ns/1ps

// Additional regression: operand dependencies, load/store boundaries,
// instruction capture, invalid instructions and reset during a pending LW.
module tb_cpu_corner;
reg sys_clk;
reg sys_rst_n;
reg [31:0] injected_inst;
wire [31:0] pc, inst, alu_result, wb_data;
integer checks, errors;

cpu_top dut (.sys_clk(sys_clk), .sys_rst_n(sys_rst_n),
             .pc(pc), .inst(inst), .alu_result(alu_result), .wb_data(wb_data));

initial begin
    sys_clk = 1'b0;
    forever #10 sys_clk = ~sys_clk;
end

function [31:0] addi;
    input [4:0] rd, rs1;
    input [11:0] immediate;
    addi = {immediate, rs1, 3'b000, rd, 7'b0010011};
endfunction

function [31:0] lw;
    input [4:0] rd, rs1;
    input [11:0] immediate;
    lw = {immediate, rs1, 3'b010, rd, 7'b0000011};
endfunction

function [31:0] sw;
    input [4:0] rs2, rs1;
    input [11:0] immediate;
    sw = {immediate[11:5], rs2, rs1, 3'b010, immediate[4:0], 7'b0100011};
endfunction

function [31:0] branch;
    input [4:0] rs1, rs2;
    input [2:0] funct3;
    input [12:0] immediate;
    branch = {immediate[12], immediate[10:5], rs2, rs1, funct3,
              immediate[4:1], immediate[11], 7'b1100011};
endfunction

task check32;
    input [8*80-1:0] name;
    input [31:0] actual, expected;
    begin
        checks = checks + 1;
        if (actual !== expected) begin
            errors = errors + 1;
            $display("[FAIL] %0s actual=%h expected=%h", name, actual, expected);
        end
    end
endtask

task tick;
    begin
        @(posedge sys_clk);
        #1;
    end
endtask

task reset_cpu;
    begin
        @(negedge sys_clk);
        sys_rst_n = 1'b0;
        #1;
        check32("reset clears PC", pc, 32'd0);
        check32("reset clears instruction latch", inst, 32'h0000_0013);
        check32("reset suppresses RAM write", {31'd0, dut.data_ram_wen}, 32'd0);
        @(negedge sys_clk);
        sys_rst_n = 1'b1;
        #1;
    end
endtask

task issue;
    input [31:0] instruction;
    input is_load;
    input [31:0] expected_pc;
    reg [31:0] saved_pc;
    begin
        saved_pc = pc;
        check32("FETCH suppresses register write", {31'd0, dut.regfile_wen}, 32'd0);
        check32("FETCH suppresses RAM write", {31'd0, dut.data_ram_wen}, 32'd0);
        injected_inst = instruction;
        tick;
        check32("FETCH holds PC", pc, saved_pc);
        check32("FETCH captures instruction", inst, instruction);
        // Changing ROM data after FETCH must not change the executing instruction.
        @(negedge sys_clk);
        injected_inst = 32'hFFFF_FFFF;
        #1;
        check32("execution uses captured instruction", inst, instruction);
        tick;
        if (is_load) begin
            check32("LW request holds PC", pc, saved_pc);
            tick;
        end
        check32("instruction commits expected PC", pc, expected_pc);
    end
endtask

initial begin
    checks = 0;
    errors = 0;
    sys_rst_n = 1'b1;
    injected_inst = 32'h0000_0013;
    // Override ROM only in this test. Synthesizable RTL has no override port.
    force dut.rom_inst = injected_inst;
    reset_cpu;

    issue(addi(5'd2, 5'd0, 12'd13), 1'b0, pc + 32'd4);
    issue(sw(5'd2, 5'd0, 12'd0), 1'b0, pc + 32'd4);
    check32("SW stores operand", dut.data_ram_inst.mem[0], 32'd13);
    // Detect a duplicate write during the following FETCH edge.
    dut.data_ram_inst.mem[0] = 32'hDEAD_BEEF;
    issue(addi(5'd2, 5'd2, 12'd1), 1'b0, pc + 32'd4);
    check32("SW is not repeated during FETCH", dut.data_ram_inst.mem[0], 32'hDEAD_BEEF);
    check32("dependent ADDI reads latest value", dut.regsfile_inst.regs[2], 32'd14);

    issue(addi(5'd1, 5'd0, 12'd1020), 1'b0, pc + 32'd4);
    issue(addi(5'd2, 5'd0, -12'd7), 1'b0, pc + 32'd4);
    issue(sw(5'd2, 5'd1, 12'd0), 1'b0, pc + 32'd4);
    check32("SW supports last RAM word", dut.data_ram_inst.mem[255], 32'hFFFF_FFF9);
    issue(lw(5'd1, 5'd1, 12'd0), 1'b1, pc + 32'd4);
    check32("LW rd=rs1 returns captured RAM data", dut.regsfile_inst.regs[1], 32'hFFFF_FFF9);
    issue(lw(5'd3, 5'd0, 12'd0), 1'b1, pc + 32'd4);
    check32("back-to-back LW uses new address", dut.regsfile_inst.regs[3], 32'hDEAD_BEEF);
    issue(lw(5'd0, 5'd0, 12'd0), 1'b1, pc + 32'd4);
    check32("LW cannot modify x0", dut.regsfile_inst.regs[0], 32'd0);

    issue(sw(5'd2, 5'd0, 12'd1), 1'b0, pc + 32'd4);
    issue(sw(5'd2, 5'd0, 12'd1024), 1'b0, pc + 32'd4);
    check32("invalid SW cannot alias word zero", dut.data_ram_inst.mem[0], 32'hDEAD_BEEF);
    issue(lw(5'd4, 5'd0, 12'd1), 1'b1, pc + 32'd4);
    check32("misaligned LW returns zero", dut.regsfile_inst.regs[4], 32'd0);
    issue(lw(5'd4, 5'd0, 12'd1024), 1'b1, pc + 32'd4);
    check32("out-of-range LW returns zero", dut.regsfile_inst.regs[4], 32'd0);

    issue(32'hFFFF_FFFF, 1'b0, pc + 32'd4);
    check32("illegal instruction leaves register unchanged", dut.regsfile_inst.regs[3], 32'hDEAD_BEEF);
    check32("illegal instruction leaves RAM unchanged", dut.data_ram_inst.mem[0], 32'hDEAD_BEEF);

    issue(addi(5'd5, 5'd0, 12'd101), 1'b0, pc + 32'd4);
    // jalr x6,0(x5): 101 with bit 0 cleared becomes 100.
    issue(32'h0002_8367, 1'b0, 32'd100);
    check32("JALR returns current PC+4", dut.regsfile_inst.regs[6], 32'd64);

    issue(branch(5'd1, 5'd3, 3'b000, 13'd8), 1'b0, 32'd104);
    issue(branch(5'd2, 5'd2, 3'b001, 13'd8), 1'b0, 32'd108);
    issue(branch(5'd0, 5'd0, 3'b000, -13'd4), 1'b0, 32'd104);

    // A pending load must be discarded by an asynchronous reset.
    @(negedge sys_clk);
    injected_inst = lw(5'd7, 5'd0, 12'd0);
    tick;
    tick;
    check32("LW not committed before LOAD_WB", dut.regsfile_inst.regs[7], 32'd0);
    reset_cpu;
    check32("reset preserves RAM", dut.data_ram_inst.mem[0], 32'hDEAD_BEEF);
    issue(addi(5'd7, 5'd0, 12'd42), 1'b0, 32'd4);
    check32("reset cancels pending load writeback", dut.regsfile_inst.regs[7], 32'd42);

    // Reset after FETCH must cancel the captured store as well.
    @(negedge sys_clk);
    injected_inst = sw(5'd7, 5'd0, 12'd0);
    tick;
    reset_cpu;
    check32("reset cancels captured SW", dut.data_ram_inst.mem[0], 32'hDEAD_BEEF);
    release dut.rom_inst;

    if (errors == 0)
        $display("tb_cpu_corner PASS: checks=%0d", checks);
    else
        $display("tb_cpu_corner FAIL: checks=%0d errors=%0d", checks, errors);
    $stop;
end

initial begin
    #5000;
    $display("tb_cpu_corner FAIL: timeout");
    $finish;
end
endmodule
