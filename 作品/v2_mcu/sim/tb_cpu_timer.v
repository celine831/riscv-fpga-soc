`timescale 1ns/1ps
module tb_cpu_timer;
reg sys_clk=0, sys_rst_n=0;
wire [31:0] pc,inst,alu_result,wb_data;
wire [7:0] gpio_out;
integer checks=0,errors=0,cycles=0;
reg saw_poll_loop=0;
cpu_top #(.ROM_PROGRAM(2),.TIMER_DEMO_PERIOD(32'd120)) dut(
    .sys_clk(sys_clk),.sys_rst_n(sys_rst_n),.pc(pc),.inst(inst),
    .alu_result(alu_result),.wb_data(wb_data),.gpio_in(8'd0),.gpio_out(gpio_out));
always #5 sys_clk=~sys_clk;
task check;
    input [8*100-1:0] name;
    input condition;
    begin checks=checks+1;
        if(condition !== 1'b1) begin errors=errors+1; $display("[FAIL] %0s",name); end
        else $display("[PASS] %0s",name);
    end
endtask
initial begin
    #2; check("reset clears GPIO and timer",gpio_out===0 && dut.timer_inst.enable===0);
    @(negedge sys_clk); sys_rst_n=1;
    while(pc !== 32'hC8 && cycles<500) begin
        @(posedge sys_clk); #1; cycles=cycles+1;
    end
    check("CPU reaches timer polling",pc===32'hC8);
    check("CPU wrote timer load",dut.timer_inst.load_value===32'd120);
    // Timer 的 SW 命令在到达轮询 PC 的 EXEC 沿锁存，下一 FETCH 沿提交。
    check("Timer start write is pending",dut.timer_write_pending===1'b1);
    @(posedge sys_clk); #1;
    check("CPU enabled one shot",dut.timer_inst.enable===1 && dut.timer_inst.periodic===0);
    check("CPU switched LED off while waiting",gpio_out===0);
    cycles=0;
    while(pc !== 32'hD8 && cycles<500) begin
        @(posedge sys_clk); #1; cycles=cycles+1;
        if(pc===32'hC8 && dut.timer_inst.expired===0 && cycles>5)
            saw_poll_loop=1;
    end
    check("CPU polls before timeout",saw_poll_loop);
    check("timer expires",dut.timer_inst.expired===1 && dut.timer_inst.enable===0);
    check("CPU reaches completion loop",pc===32'hD8);
    check("CPU writes LED one after expiration",gpio_out===1);
    repeat(10) begin @(posedge sys_clk); #1; end
    check("completion remains stable",pc===32'hD8 && gpio_out===1);
    #2; sys_rst_n=0; #1;
    check("reset immediately clears output and timer",gpio_out===0 && dut.timer_inst.expired===0);
    if(errors==0) $display("tb_cpu_timer PASS: checks=%0d",checks);
    else $display("tb_cpu_timer FAIL: checks=%0d errors=%0d",checks,errors);
    $finish;
end
initial begin #20000; errors=errors+1; $display("tb_cpu_timer FAIL: timeout"); $finish; end
endmodule
