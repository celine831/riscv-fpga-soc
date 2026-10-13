`timescale 1ns/1ps

module tb_fpga_top;
reg sys_clk, sys_rst_n;
wire led_run, led_done;
integer checks, errors, cycles;
reg previous_run;
reg saw_toggle;

// Small heartbeat bit keeps this simulation short; hardware default stays 25.
fpga_top #(.HEARTBEAT_BIT(2), .LED_ACTIVE_LOW(1)) dut
    (.sys_clk(sys_clk), .sys_rst_n(sys_rst_n), .led_run(led_run), .led_done(led_done));

initial begin
    sys_clk = 1'b0;
    forever #10 sys_clk = ~sys_clk;
end

task check;
    input [8*80-1:0] name;
    input actual, expected;
    begin
        checks = checks + 1;
        if (actual !== expected) begin
            errors = errors + 1;
            $display("[FAIL] %0s actual=%b expected=%b", name, actual, expected);
        end
    end
endtask

task wait_done;
    begin
        cycles = 0;
        saw_toggle = 1'b0;
        previous_run = led_run;
        while ((led_done !== 1'b0) && (cycles < 100)) begin
            @(posedge sys_clk);
            #1;
            cycles = cycles + 1;
            if (led_run !== previous_run)
                saw_toggle = 1'b1;
            previous_run = led_run;
        end
        check("program reaches completion", led_done, 1'b0);
        check("heartbeat toggles", saw_toggle, 1'b1);
        check("program result x17=31", dut.cpu_top_inst.regsfile_inst.regs[17] == 32'd31, 1'b1);
        repeat (8) begin
            @(posedge sys_clk);
            #1;
            check("completion LED remains on", led_done, 1'b0);
            check("PC remains at 0x50", dut.pc == 32'h0000_0050, 1'b1);
        end
    end
endtask

initial begin
    checks = 0;
    errors = 0;
    sys_rst_n = 1'b1;
    #2;
    sys_rst_n = 1'b0;
    #1;
    check("reset turns heartbeat LED off", led_run, 1'b1);
    check("reset turns completion LED off", led_done, 1'b1);
    @(negedge sys_clk);
    sys_rst_n = 1'b1;
    @(posedge sys_clk);
    #1;
    check("first release edge still holds CPU reset", dut.cpu_rst_n, 1'b0);
    @(posedge sys_clk);
    #1;
    check("second release edge releases CPU", dut.cpu_rst_n, 1'b1);
    wait_done;
    @(negedge sys_clk);
    sys_rst_n = 1'b0;
    #1;
    check("button resets heartbeat immediately", led_run, 1'b1);
    check("button clears completion immediately", led_done, 1'b1);
    @(negedge sys_clk);
    sys_rst_n = 1'b1;
    wait_done;
    if (errors == 0)
        $display("tb_fpga_top PASS: checks=%0d", checks);
    else
        $display("tb_fpga_top FAIL: checks=%0d errors=%0d", checks, errors);
    $stop;
end

initial begin
    #5000;
    $display("tb_fpga_top FAIL: timeout");
    $finish;
end
endmodule
