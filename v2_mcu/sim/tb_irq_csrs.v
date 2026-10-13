`timescale 1ns/1ps
module tb_irq_csrs;
reg sys_clk=0,sys_rst_n=0,csr_write=0,trap=0,mret=0,timer_irq=0;
reg [11:0] csr_addr=0;
reg [31:0] csr_wdata=0,trap_pc=0;
wire [31:0] csr_rdata,mtvec,mepc,mcause;
wire irq_request;
integer checks=0,errors=0;
irq_csrs dut(.sys_clk(sys_clk),.sys_rst_n(sys_rst_n),
    .csr_addr(csr_addr),.csr_wdata(csr_wdata),.csr_write(csr_write),
    .trap(trap),.trap_pc(trap_pc),.mret(mret),.timer_irq(timer_irq),
    .csr_rdata(csr_rdata),.irq_request(irq_request),
    .mtvec(mtvec),.mepc(mepc),.mcause(mcause));
always #5 sys_clk=~sys_clk;
task check;
    input [8*90-1:0] name;
    input condition;
    begin
        checks=checks+1;
        if(condition!==1'b1) begin errors=errors+1;$display("[FAIL] %0s",name);end
        else $display("[PASS] %0s",name);
    end
endtask
task write_csr;
    input [11:0] address;
    input [31:0] value;
    begin
        @(negedge sys_clk);csr_addr=address;csr_wdata=value;csr_write=1;
        @(posedge sys_clk);#1;
        @(negedge sys_clk);csr_write=0;
    end
endtask
initial begin
    #2;check("reset masks local timer",irq_request===0 && mtvec===0);
    @(negedge sys_clk);sys_rst_n=1;
    write_csr(12'h305,32'h00000203);
    check("mtvec direct mode aligns base",mtvec===32'h200);
    write_csr(12'h304,32'h00010000);
    csr_addr=12'h304;#1;
    check("mie enables only local bit16",csr_rdata===32'h00010000);
    timer_irq=1;#1;
    check("global MIE still masks pending source",irq_request===0);
    csr_addr=12'h344;#1;
    check("mip reflects sticky Timer",csr_rdata===32'h00010000);
    write_csr(12'h300,32'h8);
    check("local pending interrupt requests trap",irq_request===1);
    @(negedge sys_clk);trap=1;trap_pc=32'h0000011C;
    @(posedge sys_clk);#1;
    check("trap records cause and interrupted PC",
          mcause===32'h80000010 && mepc===32'h11C);
    check("trap disables nesting",irq_request===0);
    @(negedge sys_clk);trap=0;timer_irq=0;mret=1;
    @(posedge sys_clk);#1;
    check("MRET restores global MIE",dut.mie_global===1 &&
          dut.mpie===1 && irq_request===0);
    #2;sys_rst_n=0;#1;
    check("external reset immediately clears CSRs",mepc===0 &&
          mcause===0 && mtvec===0 && irq_request===0);
    if(errors==0) $display("tb_irq_csrs PASS: checks=%0d",checks);
    else $display("tb_irq_csrs FAIL: checks=%0d errors=%0d",checks,errors);
    $finish;
end
initial begin #3000;errors=errors+1;$display("tb_irq_csrs FAIL: timeout");$finish;end
endmodule
