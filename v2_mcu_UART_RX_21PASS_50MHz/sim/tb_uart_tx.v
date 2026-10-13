`timescale 1ns/1ps
module tb_uart_tx;
reg sys_clk=0,sys_rst_n=0,sel=0,wen=0,ren=0;
reg [31:0] addr=0,wdata=0;
wire [31:0] rdata;
wire tx;
integer checks=0,errors=0,i;
reg [7:0] received;
uart_tx #(.CLKS_PER_BIT(8)) dut(
    .sys_clk(sys_clk),.sys_rst_n(sys_rst_n),.sel(sel),.wen(wen),
    .ren(ren),.addr(addr),.wdata(wdata),.rdata(rdata),.tx(tx));
always #5 sys_clk=~sys_clk;
task check;
    input [8*90-1:0] name;
    input condition;
    begin checks=checks+1;
        if(condition !== 1'b1) begin errors=errors+1; $display("[FAIL] %0s",name); end
        else $display("[PASS] %0s",name);
    end
endtask
task write_reg;
    input [31:0] a,data;
    begin
        @(negedge sys_clk); sel=1;wen=1;addr=a;wdata=data;
        @(posedge sys_clk); #1;
        @(negedge sys_clk); sel=0;wen=0;
    end
endtask
task read_reg;
    input [31:0] a,expected;
    begin
        @(negedge sys_clk);sel=1;ren=1;addr=a;
        @(posedge sys_clk);#1;
        check("synchronous UART register read",rdata===expected);
        @(negedge sys_clk);sel=0;ren=0;
    end
endtask
initial begin
    #2;check("reset gives idle high",tx===1 && dut.busy===0 && rdata===0);
    @(negedge sys_clk);sys_rst_n=1;
    write_reg(32'h1000_2002,32'hFF);
    check("misaligned write ignored",tx===1 && dut.busy===0);
    read_reg(32'h1000_2004,32'd0);
    write_reg(32'h1000_2000,32'h141);
    check("start bit low, busy asserted",tx===0 && dut.busy===1);
    write_reg(32'h1000_2000,32'h42);
    check("busy write cannot replace current frame",dut.busy===1 &&
        dut.frame[8:1]===8'h41);
    read_reg(32'h1000_2004,32'd1);
    // 前面已走过数个时钟，随后只检查完整后半帧及空闲。
    repeat(85) begin @(posedge sys_clk);#1; end
    check("transmission returns to idle",tx===1 && dut.busy===0);
    write_reg(32'h1000_2000,32'hA5);
    check("new start bit low",tx===0);
    for(i=0;i<8;i=i+1) begin
        repeat(8) @(posedge sys_clk);#1;
        received[i]=tx;
    end
    repeat(8) @(posedge sys_clk);#1;
    check("8N1 data bits sent LSB first",received===8'hA5);
    check("stop bit high",tx===1 && dut.busy===1);
    repeat(8) @(posedge sys_clk);#1;
    check("full stop bit then idle",tx===1 && dut.busy===0);
    #2;sys_rst_n=0;#1;
    check("asynchronous reset restores idle",tx===1 && dut.busy===0);
    if(errors==0) $display("tb_uart_tx PASS: checks=%0d",checks);
    else $display("tb_uart_tx FAIL: checks=%0d errors=%0d",checks,errors);
    $finish;
end
initial begin #20000;errors=errors+1;$display("tb_uart_tx FAIL: timeout");$finish;end
endmodule
