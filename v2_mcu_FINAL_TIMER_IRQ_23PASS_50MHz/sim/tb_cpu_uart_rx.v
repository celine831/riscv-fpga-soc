`timescale 1ns/1ps
module tb_cpu_uart_rx;
reg sys_clk=0,sys_rst_n=0,uart_rx_pin=1;
wire [31:0] pc,inst,alu_result,wb_data;
wire [7:0] gpio_out;
wire uart_tx_pin;
integer checks=0,errors=0,cycles=0;
cpu_top #(.ROM_PROGRAM(4),.TIMER_DEMO_PERIOD(32'd120),
    .UART_CLKS_PER_BIT(16)) dut(
    .sys_clk(sys_clk),.sys_rst_n(sys_rst_n),.pc(pc),.inst(inst),
    .alu_result(alu_result),.wb_data(wb_data),.gpio_in(8'd0),
    .gpio_out(gpio_out),.uart_tx_pin(uart_tx_pin),.uart_rx_pin(uart_rx_pin));
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
task wait_gpio;
    input [7:0] expected;
    begin
        cycles=0;
        while(gpio_out!==expected && cycles<200) begin
            @(posedge sys_clk);#1;cycles=cycles+1;
        end
        check("CPU updates GPIO from UART command",gpio_out===expected);
        cycles=0;
        while(dut.uart_rx_inst.valid!==0 && cycles<200) begin
            @(posedge sys_clk);#1;cycles=cycles+1;
        end
        check("CPU acknowledges received byte",dut.uart_rx_inst.valid===0);
    end
endtask
initial begin
    #2;check("reset clears GPIO and RX valid",gpio_out===0 && dut.uart_rx_inst.valid===0);
    @(negedge sys_clk);sys_rst_n=1;
    cycles=0;
    while(pc!==32'h118 && cycles<1500) begin
        @(posedge sys_clk);#1;cycles=cycles+1;
    end
    check("CPU reaches UART RX polling after TX completes",
        pc===32'h118 && gpio_out===1 && dut.timer_inst.expired===1 &&
        dut.uart_inst.busy===0);
    send_byte(8'h30);
    wait_gpio(8'd0);
    send_byte(8'h31);
    wait_gpio(8'd1);
    send_byte(8'h58);
    repeat(80) begin @(posedge sys_clk);#1;end
    check("unrecognized character keeps GPIO state",
        gpio_out===1 && dut.uart_rx_inst.valid===0);
    send_byte(8'h30);
    wait_gpio(8'd0);
    #2;sys_rst_n=0;#1;
    check("reset immediately clears CPU RX and GPIO",
        gpio_out===0 && dut.uart_rx_inst.valid===0 && uart_tx_pin===1);
    if(errors==0) $display("tb_cpu_uart_rx PASS: checks=%0d",checks);
    else $display("tb_cpu_uart_rx FAIL: checks=%0d errors=%0d",checks,errors);
    $finish;
end
initial begin #80000;errors=errors+1;$display("tb_cpu_uart_rx FAIL: timeout");$finish;end
endmodule
