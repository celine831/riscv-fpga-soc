`timescale 1ns/1ps
module tb_fpga_timer;
reg sys_clk=0,sys_rst_n=1;
wire run_low,done_low,run_high,done_high;
integer checks=0,errors=0,cycles=0;
reg saw_heartbeat_on=0,saw_heartbeat_off=0;
fpga_top #(.HEARTBEAT_BIT(3),.LED_ACTIVE_LOW(1),
    .ROM_PROGRAM(2),.TIMER_DEMO_PERIOD(32'd120)) low_dut(
    .sys_clk(sys_clk),.sys_rst_n(sys_rst_n),.led_run(run_low),.led_done(done_low));
fpga_top #(.HEARTBEAT_BIT(3),.LED_ACTIVE_LOW(0),
    .ROM_PROGRAM(2),.TIMER_DEMO_PERIOD(32'd120)) high_dut(
    .sys_clk(sys_clk),.sys_rst_n(sys_rst_n),.led_run(run_high),.led_done(done_high));
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
    #2; sys_rst_n=0; #1;
    check("reset switches both LEDs off",run_low===1 && done_low===1 &&
        run_high===0 && done_high===0);
    @(negedge sys_clk); sys_rst_n=1;
    while(low_dut.pc !== 32'hC8 && cycles<500) begin
        @(posedge sys_clk); #1; cycles=cycles+1;
        if(run_high===1) saw_heartbeat_on=1;
        if(run_high===0) saw_heartbeat_off=1;
    end
    check("heartbeat continues toggling",saw_heartbeat_on && saw_heartbeat_off);
    check("timer starts while completion LED is off",
        low_dut.pc===32'hC8 && low_dut.cpu_top_inst.timer_inst.enable===1 &&
        done_low===1 && done_high===0);
    cycles=0;
    while(low_dut.pc !== 32'hD8 && cycles<500) begin
        @(posedge sys_clk); #1; cycles=cycles+1;
        check("LED polarity agrees",run_low===!run_high && done_low===!done_high);
    end
    check("completion LED lights after timer expiry",
        low_dut.pc===32'hD8 && low_dut.cpu_top_inst.timer_inst.expired===1 &&
        done_low===0 && done_high===1);
    #2; sys_rst_n=0; #1;
    check("reset immediately switches LEDs off again",
        run_low===1 && done_low===1 && run_high===0 && done_high===0);
    if(errors==0) $display("tb_fpga_timer PASS: checks=%0d",checks);
    else $display("tb_fpga_timer FAIL: checks=%0d errors=%0d",checks,errors);
    $finish;
end
initial begin #20000; errors=errors+1; $display("tb_fpga_timer FAIL: timeout"); $finish; end
endmodule
