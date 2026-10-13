`timescale 1ns/1ps
module tb_cpu_uart;
reg sys_clk=0,sys_rst_n=0;
wire [31:0] pc,inst,alu_result,wb_data;
wire [7:0] gpio_out;
wire uart_tx_pin;
integer checks=0,errors=0,cycles=0,i,j;
reg [7:0] received[0:2];
cpu_top #(.ROM_PROGRAM(3),.TIMER_DEMO_PERIOD(32'd120),
    .UART_CLKS_PER_BIT(8)) dut(
    .sys_clk(sys_clk),.sys_rst_n(sys_rst_n),.pc(pc),.inst(inst),
    .alu_result(alu_result),.wb_data(wb_data),.gpio_in(8'd0),
    .gpio_out(gpio_out),.uart_tx_pin(uart_tx_pin));
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
    #2;check("reset UART idle",uart_tx_pin===1);
    @(negedge sys_clk);sys_rst_n=1;
    fork
        begin
            for(j=0;j<3;j=j+1) begin
                @(negedge uart_tx_pin);
                repeat(4) @(posedge sys_clk);#1;
                check("UART start bit",uart_tx_pin===0);
                for(i=0;i<8;i=i+1) begin
                    repeat(8) @(posedge sys_clk);#1;
                    received[j][i]=uart_tx_pin;
                end
                repeat(8) @(posedge sys_clk);#1;
                check("UART stop bit",uart_tx_pin===1);
            end
        end
        begin
            while(pc!==32'h114 && cycles<4000) begin
                @(posedge sys_clk);#1;cycles=cycles+1;
            end
            check("program reaches final UART loop",pc===32'h114);
        end
    join
    check("timer expired before serial output",dut.timer_inst.expired===1 && gpio_out===1);
    check("first byte is O",received[0]===8'h4F);
    check("second byte is K",received[1]===8'h4B);
    check("third byte is newline",received[2]===8'h0A);
    check("UART becomes idle after final byte",dut.uart_inst.busy===0 && uart_tx_pin===1);
    #2;sys_rst_n=0;#1;
    check("reset clears timer, GPIO and UART",
        gpio_out===0 && dut.timer_inst.expired===0 && uart_tx_pin===1);
    if(errors==0) $display("tb_cpu_uart PASS: checks=%0d",checks);
    else $display("tb_cpu_uart FAIL: checks=%0d errors=%0d",checks,errors);
    $finish;
end
initial begin #50000;errors=errors+1;$display("tb_cpu_uart FAIL: timeout");$finish;end
endmodule
