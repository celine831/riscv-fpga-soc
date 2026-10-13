`timescale 1ns/1ps
module tb_fpga_uart_rx;
reg sys_clk=0,sys_rst_n=1,uart_rx_pin=1;
wire led_run,led_done,uart_tx_pin;
integer checks=0,errors=0,cycles=0;
fpga_top #(.HEARTBEAT_BIT(3),.LED_ACTIVE_LOW(1),
    .ROM_PROGRAM(4),
    .TIMER_DEMO_PERIOD(32'd120),.UART_CLKS_PER_BIT(16)) dut(
    .sys_clk(sys_clk),.sys_rst_n(sys_rst_n),
    .led_run(led_run),.led_done(led_done),
    .uart_tx_pin(uart_tx_pin),.uart_rx_pin(uart_rx_pin));
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
        @(negedge sys_clk);uart_rx_pin=0;
        repeat(16) @(negedge sys_clk);
        for(k=0;k<8;k=k+1) begin
            uart_rx_pin=data[k];
            repeat(16) @(negedge sys_clk);
        end
        uart_rx_pin=1;
        repeat(16) @(negedge sys_clk);
    end
endtask
initial begin
    #2;sys_rst_n=0;#1;
    check("top reset keeps LEDs off and TX idle",
        led_run===1 && led_done===1 && uart_tx_pin===1);
    @(negedge sys_clk);sys_rst_n=1;
    cycles=0;
    while(dut.pc!==32'h118 && cycles<1500) begin
        @(posedge sys_clk);#1;cycles=cycles+1;
    end
    check("top waits for command after Timer and TX",
        dut.pc===32'h118 && led_done===0 && uart_tx_pin===1);
    send_byte(8'h30);
    cycles=0;
    while(led_done!==1 && cycles<200) begin @(posedge sys_clk);#1;cycles=cycles+1;end
    check("sending ASCII 0 turns LED off",led_done===1);
    repeat(50) begin @(posedge sys_clk);#1;end
    send_byte(8'h31);
    cycles=0;
    while(led_done!==0 && cycles<200) begin @(posedge sys_clk);#1;cycles=cycles+1;end
    check("sending ASCII 1 turns LED on",led_done===0);
    #2;sys_rst_n=0;#1;
    check("top reset immediately switches LEDs off",led_run===1 && led_done===1);
    if(errors==0) $display("tb_fpga_uart_rx PASS: checks=%0d",checks);
    else $display("tb_fpga_uart_rx FAIL: checks=%0d errors=%0d",checks,errors);
    $finish;
end
initial begin #80000;errors=errors+1;$display("tb_fpga_uart_rx FAIL: timeout");$finish;end
endmodule
