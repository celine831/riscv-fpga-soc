`timescale 1ns/1ps
module tb_gpio;
reg sys_clk = 1'b0;
reg sys_rst_n;
reg sel, wen, ren;
reg [31:0] addr, wdata;
reg [7:0] gpio_in;
wire [7:0] gpio_out;
wire [31:0] rdata;
integer checks = 0;
integer errors = 0;

gpio dut(.sys_clk(sys_clk), .sys_rst_n(sys_rst_n),
    .sel(sel), .wen(wen), .ren(ren), .addr(addr), .wdata(wdata),
    .gpio_in(gpio_in), .gpio_out(gpio_out), .rdata(rdata));
always #5 sys_clk = ~sys_clk;

task check32;
    input [8*96-1:0] name;
    input [31:0] actual, expected;
    begin
        checks = checks + 1;
        if (actual !== expected)
        begin
            errors = errors + 1;
            $display("[FAIL] %0s actual=%h expected=%h", name, actual, expected);
        end
        else
            $display("[PASS] %0s", name);
    end
endtask

task access;
    input select, write_en, read_en;
    input [31:0] address, data;
    begin
        @(negedge sys_clk);
        sel = select; wen = write_en; ren = read_en;
        addr = address; wdata = data;
        @(posedge sys_clk); #1;
    end
endtask

initial
begin
    sys_rst_n=1; sel=0; wen=0; ren=0;
    addr=0; wdata=0; gpio_in=0;
    #2; sys_rst_n=0; #1;
    check32("asynchronous reset clears output", gpio_out, 0);
    check32("asynchronous reset clears read data", rdata, 0);
    access(1,1,1,32'h10000000,32'hFFFFFFFF);
    check32("reset prevents writes", gpio_out, 0);
    @(negedge sys_clk); sys_rst_n=1; sel=0; wen=0; ren=0;

    // 输出写入、同步读回，以及32位到8位截取。
    @(negedge sys_clk);
    sel=1; wen=1; addr=32'h10000000; wdata=5;
    #1; check32("output holds before write edge", gpio_out, 0);
    @(posedge sys_clk); #1;
    check32("output updates at write edge", gpio_out, 5);
    @(negedge sys_clk); wen=0; ren=1;
    #1; check32("read data holds before read edge", rdata, 0);
    @(posedge sys_clk); #1;
    check32("read data arrives after read edge", rdata, 5);
    access(1,1,0,32'h10000000,32'h123401AA);
    check32("write keeps only low eight bits", gpio_out, 32'hAA);
    access(1,0,1,32'h10000000,0);
    check32("output read is zero extended", rdata, 32'hAA);

    access(0,1,1,32'h10000000,0);
    check32("unselected writes are ignored", gpio_out,32'hAA);
    check32("unselected reads return zero",rdata,0);
    access(1,0,0,32'h10000000,0);
    check32("disabled writes preserve output",gpio_out,32'hAA);
    check32("no read request returns zero",rdata,0);
    access(1,1,0,32'h10000004,0);
    check32("input register cannot be written",gpio_out,32'hAA);
    access(1,1,0,32'h10000008,0);
    check32("invalid offset writes are ignored",gpio_out,32'hAA);
    access(1,1,0,32'h10000001,0);
    check32("unaligned writes are ignored",gpio_out,32'hAA);
    access(1,1,0,32'h20000000,0);
    check32("different base writes are ignored",gpio_out,32'hAA);
    access(1,0,1,32'h10000008,0);
    check32("invalid offset reads return zero",rdata,0);
    access(1,0,1,32'h10000001,0);
    check32("unaligned reads return zero",rdata,0);
    access(1,0,1,32'h20000000,0);
    check32("different base reads return zero",rdata,0);

    // 输入经过两级同步，不在改变引脚时立即改变同步值。
    @(negedge sys_clk); sel=0; ren=0; gpio_in=8'hA6;
    #1; check32("input change is not immediately visible",dut.gpio_in_sync,0);
    @(posedge sys_clk); #1;
    check32("first synchronization edge keeps old input",dut.gpio_in_sync,0);
    @(posedge sys_clk); #1;
    check32("second synchronization edge captures input",dut.gpio_in_sync,32'hA6);
    access(1,0,1,32'h10000004,0);
    check32("input read is zero extended",rdata,32'hA6);
    @(negedge sys_clk); gpio_in=8'h3C; sel=0; ren=0;
    repeat (2) @(posedge sys_clk);
    #1;
    access(1,0,1,32'h10000004,0);
    check32("input read follows later input changes",rdata,32'h3C);

    access(1,1,1,32'h10000000,32'h55);
    check32("simultaneous read returns old output",rdata,32'hAA);
    check32("simultaneous write updates output",gpio_out,32'h55);
    access(1,0,1,32'h10000000,0);
    check32("next read returns new output",rdata,32'h55);
    #2; sys_rst_n=0; #1;
    check32("running output clears asynchronously",gpio_out,0);
    check32("running read data clears asynchronously",rdata,0);
    check32("input synchronizer clears",dut.gpio_in_sync,0);
    @(negedge sys_clk); sys_rst_n=1; sel=0; ren=0; wen=0;
    access(1,1,0,32'h10000000,32'h81);
    check32("writes work after reset",gpio_out,32'h81);
    if (errors == 0)
        $display("tb_gpio PASS: checks=%0d",checks);
    else
        $display("tb_gpio FAIL: checks=%0d errors=%0d",checks,errors);
    $finish;
end
initial begin #10000; errors=errors+1; $display("tb_gpio FAIL: timeout"); $finish; end
endmodule
