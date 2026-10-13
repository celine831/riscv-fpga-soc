`timescale 1ns/1ps
module tb_timer;
reg sys_clk=0, sys_rst_n=0, sel=0, wen=0, ren=0;
reg [31:0] addr=0, wdata=0;
wire [31:0] rdata;
integer checks=0, errors=0, i;
timer dut(.sys_clk(sys_clk),.sys_rst_n(sys_rst_n),.sel(sel),
    .wen(wen),.ren(ren),.addr(addr),.wdata(wdata),.rdata(rdata));
always #5 sys_clk=~sys_clk;
task check;
    input [8*90-1:0] name;
    input condition;
    begin
        checks=checks+1;
        if(condition !== 1'b1) begin
            errors=errors+1; $display("[FAIL] %0s",name);
        end else $display("[PASS] %0s",name);
    end
endtask
task write_reg;
    input [31:0] a, data;
    begin
        @(negedge sys_clk); sel=1; wen=1; ren=0; addr=a; wdata=data;
        @(posedge sys_clk); #1;
        @(negedge sys_clk); sel=0; wen=0;
    end
endtask
task read_reg;
    input [31:0] a;
    input [31:0] expected;
    begin
        @(negedge sys_clk); sel=1; ren=1; addr=a;
        @(posedge sys_clk); #1;
        check("synchronous MMIO read",rdata===expected);
        @(negedge sys_clk); sel=0; ren=0;
    end
endtask
initial begin
    #2; check("asynchronous reset clears timer",dut.enable===0 && dut.expired===0 && rdata===0);
    @(negedge sys_clk); sys_rst_n=1;
    write_reg(32'h1000_1004,32'd8);
    read_reg(32'h1000_1004,32'd8);
    write_reg(32'h1000_1000,32'd1);
    check("one shot starts",dut.enable===1 && dut.periodic===0 && dut.count_value!==0);
    for(i=0;i<15;i=i+1) begin @(posedge sys_clk); #1; end
    check("one shot expires and stops",dut.expired===1 && dut.enable===0 && dut.count_value===0);
    read_reg(32'h1000_100C,32'd1);
    write_reg(32'h1000_100C,32'd0);
    check("writing zero does not clear sticky status",dut.expired===1);
    write_reg(32'h1000_100C,32'd1);
    read_reg(32'h1000_100C,32'd0);
    write_reg(32'h1000_1004,32'd3);
    write_reg(32'h1000_1000,32'd3);
    check("periodic starts",dut.enable===1 && dut.periodic===1);
    for(i=0;i<12;i=i+1) begin @(posedge sys_clk); #1; end
    check("periodic reloads and stays enabled",dut.enable===1 && dut.count_value!==0 && dut.expired===1);
    write_reg(32'h1000_1000,32'd0);
    check("CTRL stops counter",dut.enable===0 && dut.count_value===0);
    write_reg(32'h1000_100C,32'd1);
    write_reg(32'h1000_1002,32'hFFFF_FFFF);
    read_reg(32'h1000_1002,32'd0);
    read_reg(32'h1000_1004,32'd3);
    #2; sys_rst_n=0; #1;
    check("reset clears active configuration",dut.load_value===0 && dut.expired===0 && dut.enable===0);
    if(errors==0) $display("tb_timer PASS: checks=%0d",checks);
    else $display("tb_timer FAIL: checks=%0d errors=%0d",checks,errors);
    $finish;
end
initial begin #10000; errors=errors+1; $display("tb_timer FAIL: timeout"); $finish; end
endmodule
