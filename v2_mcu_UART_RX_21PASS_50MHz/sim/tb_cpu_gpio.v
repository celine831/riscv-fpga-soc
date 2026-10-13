`timescale 1ns/1ps
module tb_cpu_gpio;
reg sys_clk = 0;
reg sys_rst_n;
reg [7:0] gpio_in;
wire [7:0] gpio_out;
wire [31:0] pc, inst, alu_result, wb_data;
integer checks=0;
integer errors=0;
integer cycles;

cpu_top #(.ROM_PROGRAM(1)) dut(
    .sys_clk(sys_clk), .sys_rst_n(sys_rst_n),
    .pc(pc), .inst(inst), .alu_result(alu_result), .wb_data(wb_data),
    .gpio_in(gpio_in), .gpio_out(gpio_out));
always #5 sys_clk=~sys_clk;

task check32;
    input [8*96-1:0] name;
    input [31:0] actual, expected;
    begin
        checks=checks+1;
        if (actual !== expected)
        begin
            errors=errors+1;
            $display("[FAIL] %0s actual=%h expected=%h",name,actual,expected);
        end
        else $display("[PASS] %0s",name);
    end
endtask
task tick;
    begin @(posedge sys_clk); #1; end
endtask
task single_step;
    input [31:0] expected_pc;
    begin tick; tick; check32("ordinary instruction advances PC",pc,expected_pc); end
endtask
task load_step;
    input [31:0] load_pc;
    input integer rd;
    input [31:0] expected;
    reg [31:0] old_value;
    begin
        check32("LW starts at expected PC",pc,load_pc);
        old_value=dut.regsfile_inst.regs[rd];
        tick; tick;
        check32("LW first cycle holds PC",pc,load_pc);
        check32("LW first cycle leaves destination unchanged",dut.regsfile_inst.regs[rd],old_value);
        check32("LW first cycle receives correct response",dut.mem_rdata,expected);
        tick; tick;
        check32("LW second cycle advances PC",pc,load_pc+4);
        check32("LW second cycle writes destination",dut.regsfile_inst.regs[rd],expected);
    end
endtask

task run_program;
    input [7:0] input_value;
    begin
        @(negedge sys_clk); sys_rst_n=0; gpio_in=input_value;
        #1;
        check32("reset clears GPIO output",gpio_out,0);
        check32("reset clears PC",pc,0);
        repeat(2) @(negedge sys_clk);
        sys_rst_n=1;
        cycles=0;
        while ((pc !== 32'h50) && (cycles < 100))
        begin tick; cycles=cycles+1; end
        check32("baseline program reaches GPIO extension",pc,32'h50);
        check32("baseline arithmetic completes",dut.regsfile_inst.regs[3],13);
        check32("baseline RAM load completes",dut.regsfile_inst.regs[9],13);
        check32("baseline completion marker",dut.regsfile_inst.regs[17],31);
        check32("baseline RAM contains 13",dut.data_ram_inst.mem[0],13);
        check32("GPIO untouched by RAM store",gpio_out,0);

        single_step(32'h54);
        check32("LUI forms GPIO base",dut.regsfile_inst.regs[18],32'h10000000);
        single_step(32'h58);
        single_step(32'h5C);
        check32("CPU SW controls GPIO",gpio_out,5);
        check32("GPIO store does not overwrite RAM",dut.data_ram_inst.mem[0],13);
        load_step(32'h5C,20,5);
        load_step(32'h60,21,{24'd0,input_value});
        single_step(32'h68);
        single_step(32'h6C);
        check32("CPU output write truncates to eight bits",gpio_out,32'hAA);
        load_step(32'h6C,22,32'hAA);
        load_step(32'h70,23,0);
        single_step(32'h78);
        check32("CPU unaligned GPIO store is ignored",gpio_out,32'hAA);
        single_step(32'h7C);
        check32("CPU cannot write GPIO input register",gpio_out,32'hAA);
        load_step(32'h7C,24,32'hAA);
        load_step(32'h80,25,13);
        single_step(32'h88);
        check32("CPU invalid offset store is ignored",gpio_out,32'hAA);
        load_step(32'h88,26,0);
        single_step(32'h90);
        single_step(32'h94);
        check32("unmapped store preserves GPIO",gpio_out,32'hAA);
        check32("unmapped store preserves RAM",dut.data_ram_inst.mem[0],13);
        load_step(32'h94,28,0);
        single_step(32'h9C);
        single_step(32'hA0);
        check32("final GPIO output is one",gpio_out,1);
        load_step(32'hA0,29,1);
        load_step(32'hA4,30,13);
        repeat(3) tick;
        check32("program stops in JAL loop",pc,32'hA8);
        check32("GPIO stays stable after completion",gpio_out,1);
        check32("zero register stays zero",dut.regsfile_inst.regs[0],0);
    end
endtask
initial
begin
    sys_rst_n=1; gpio_in=0;
    run_program(8'hA6);
    // 再次复位重跑，验证同步输入与程序不依赖第一次运行的状态。
    run_program(8'h3C);
    #2; sys_rst_n=0; #1;
    check32("final asynchronous reset clears GPIO",gpio_out,0);
    check32("final asynchronous reset masks memory data",dut.mem_rdata,0);
    if (errors == 0)
        $display("tb_cpu_gpio PASS: checks=%0d",checks);
    else $display("tb_cpu_gpio FAIL: checks=%0d errors=%0d",checks,errors);
    $finish;
end
initial begin #20000; errors=errors+1; $display("tb_cpu_gpio FAIL: timeout"); $finish; end
endmodule
