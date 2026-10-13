`timescale 1ns/1ps
module tb_uart_rx;
reg sys_clk=0,sys_rst_n=0,rx_pin=1,sel=0,wen=0,ren=0;
reg [31:0] addr=0,wdata=0;
wire [31:0] rdata;
integer checks=0,errors=0,i;
uart_rx #(.CLKS_PER_BIT(16)) dut(
    .sys_clk(sys_clk),.sys_rst_n(sys_rst_n),.rx_pin(rx_pin),
    .sel(sel),.wen(wen),.ren(ren),.addr(addr),.wdata(wdata),.rdata(rdata));
always #5 sys_clk=~sys_clk;
task check;
    input [8*100-1:0] name;
    input condition;
    begin checks=checks+1;
        if(condition!==1'b1) begin errors=errors+1;$display("[FAIL] %0s",name);end
        else $display("[PASS] %0s",name);
    end
endtask
task send_byte;
    input [7:0] data;
    integer k;
    begin
        @(negedge sys_clk);rx_pin=0;
        repeat(16) @(negedge sys_clk);
        for(k=0;k<8;k=k+1) begin
            rx_pin=data[k];
            repeat(16) @(negedge sys_clk);
        end
        rx_pin=1;
        repeat(16) @(negedge sys_clk);
    end
endtask
task write_reg;
    input [31:0] a,d;
    begin
        @(negedge sys_clk);sel=1;wen=1;addr=a;wdata=d;
        @(posedge sys_clk);#1;
        @(negedge sys_clk);sel=0;wen=0;
    end
endtask
task read_reg;
    input [31:0] a,expected;
    begin
        @(negedge sys_clk);sel=1;ren=1;addr=a;
        @(posedge sys_clk);#1;
        check("RX synchronous register read",rdata===expected);
        @(negedge sys_clk);sel=0;ren=0;
    end
endtask
initial begin
    #2;check("reset clears valid and data",dut.valid===0 && rdata===0);
    @(negedge sys_clk);sys_rst_n=1;
    @(negedge sys_clk);rx_pin=0;
    repeat(2) @(negedge sys_clk);rx_pin=1;
    repeat(25) @(negedge sys_clk);
    check("short start glitch rejected",dut.valid===0);
    send_byte(8'hA5);
    check("first byte captured",dut.valid===1 && dut.rx_data===8'hA5);
    read_reg(32'h1000_3004,32'd1);
    read_reg(32'h1000_3000,32'hA5);
    send_byte(8'h5A);
    check("unacknowledged byte stays stable",dut.valid===1 && dut.rx_data===8'hA5);
    write_reg(32'h1000_3004,32'd0);
    check("writing zero keeps valid",dut.valid===1);
    write_reg(32'h1000_3004,32'd1);
    read_reg(32'h1000_3004,32'd0);
    send_byte(8'h5A);
    read_reg(32'h1000_3000,32'h5A);
    read_reg(32'h1000_3002,32'd0);
    #2;sys_rst_n=0;#1;
    check("asynchronous reset clears receive state",dut.valid===0 && dut.rx_data===0);
    if(errors==0) $display("tb_uart_rx PASS: checks=%0d",checks);
    else $display("tb_uart_rx FAIL: checks=%0d errors=%0d",checks,errors);
    $finish;
end
initial begin #30000;errors=errors+1;$display("tb_uart_rx FAIL: timeout");$finish;end
endmodule
