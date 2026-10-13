`timescale 1ns/1ps
module tb_fpga_uart;
reg sys_clk=0,sys_rst_n=1;
wire led_run,led_done,uart_tx_pin;
integer checks=0,errors=0,cycles=0;
fpga_top #(.HEARTBEAT_BIT(3),.LED_ACTIVE_LOW(1),.ROM_PROGRAM(3),
    .TIMER_DEMO_PERIOD(32'd120),.UART_CLKS_PER_BIT(8)) dut(
    .sys_clk(sys_clk),.sys_rst_n(sys_rst_n),
    .led_run(led_run),.led_done(led_done),.uart_tx_pin(uart_tx_pin));
always #5 sys_clk=~sys_clk;
task check;
    input [8*90-1:0] name;
    input condition;
    begin checks=checks+1;
        if(condition !== 1'b1) begin errors=errors+1;$display("[FAIL] %0s",name);end
        else $display("[PASS] %0s",name);
    end
endtask
initial begin
    #2;sys_rst_n=0;#1;
    check("top reset turns LEDs off and UART idle",
        led_run===1 && led_done===1 && uart_tx_pin===1);
    @(negedge sys_clk);sys_rst_n=1;
    while(dut.pc!==32'hC8 && cycles<500) begin
        @(posedge sys_clk);#1;cycles=cycles+1;
    end
    check("top Timer starts with LED off and serial idle",
        dut.pc===32'hC8 && led_done===1 && uart_tx_pin===1);
    cycles=0;
    while(dut.pc!==32'hD8 && cycles<500) begin
        @(posedge sys_clk);#1;cycles=cycles+1;
    end
    check("Timer expiry lights LED before UART program",
        dut.pc===32'hD8 && led_done===0 && dut.cpu_top_inst.timer_inst.expired===1);
    cycles=0;
    while(uart_tx_pin!==0 && cycles<100) begin
        @(posedge sys_clk);#1;cycles=cycles+1;
    end
    check("top UART pin transmits start bit",uart_tx_pin===0);
    #2;sys_rst_n=0;#1;
    check("top reset aborts UART and clears LEDs",
        uart_tx_pin===1 && led_run===1 && led_done===1);
    if(errors==0) $display("tb_fpga_uart PASS: checks=%0d",checks);
    else $display("tb_fpga_uart FAIL: checks=%0d errors=%0d",checks,errors);
    $finish;
end
initial begin #20000;errors=errors+1;$display("tb_fpga_uart FAIL: timeout");$finish;end
endmodule
