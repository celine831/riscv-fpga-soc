`timescale 1ns/1ps
module tb_fpga_top;
reg sys_clk=0;
reg sys_rst_n;
wire run_low, done_low, run_high, done_high;
integer checks=0;
integer errors=0;
reg heartbeat_seen;
reg gpio_transition_seen;
fpga_top #(.HEARTBEAT_BIT(3),.LED_ACTIVE_LOW(1),.ROM_PROGRAM(1)) dut_low(
    .sys_clk(sys_clk),.sys_rst_n(sys_rst_n),.led_run(run_low),.led_done(done_low));
fpga_top #(.HEARTBEAT_BIT(3),.LED_ACTIVE_LOW(0),.ROM_PROGRAM(1)) dut_high(
    .sys_clk(sys_clk),.sys_rst_n(sys_rst_n),.led_run(run_high),.led_done(done_high));
always #5 sys_clk=~sys_clk;
task check;
    input [8*96-1:0] name;
    input condition;
    begin
        checks=checks+1;
        if (condition !== 1'b1)
        begin errors=errors+1; $display("[FAIL] %0s",name); end
        else $display("[PASS] %0s",name);
    end
endtask
initial
begin
    sys_rst_n=1; heartbeat_seen=0; gpio_transition_seen=0;
    #2; sys_rst_n=0; #1;
    check("active-low LEDs are off during reset",run_low===1 && done_low===1);
    check("active-high LEDs are off during reset",run_high===0 && done_high===0);
    @(negedge sys_clk); sys_rst_n=1;
    @(posedge sys_clk); #1;
    check("first release edge keeps CPU reset asserted",dut_low.cpu_rst_n===0);
    @(posedge sys_clk); #1;
    check("second release edge releases CPU reset",dut_low.cpu_rst_n===1);
    check("CPU has not advanced on release edge",dut_low.pc===0);
    repeat(200)
    begin
        @(posedge sys_clk); #1;
        if(run_high===1) heartbeat_seen=1;
        if(dut_low.gpio_out===8'hAA) gpio_transition_seen=1;
        check("LED polarity follows logical values",
            run_low===!run_high && done_low===!done_high &&
            done_high===dut_high.gpio_out[0]);
    end
    check("heartbeat toggles",heartbeat_seen);
    check("CPU-controlled LED output changed during program",gpio_transition_seen);
    check("GPIO program completed",dut_low.pc===32'hA8);
    check("CPU wrote final output one",dut_low.gpio_out===8'd1);
    check("active-low final GPIO LED is on",done_low===0);
    check("active-high final GPIO LED is on",done_high===1);
    #2; sys_rst_n=0; #1;
    check("external reset immediately resets CPU",dut_low.cpu_rst_n===0);
    check("external reset immediately switches LEDs off",run_low===1 && done_low===1);
    if(errors==0) $display("tb_fpga_top PASS: checks=%0d",checks);
    else $display("tb_fpga_top FAIL: checks=%0d errors=%0d",checks,errors);
    $finish;
end
initial begin #20000; errors=errors+1; $display("tb_fpga_top FAIL: timeout"); $finish; end
endmodule
