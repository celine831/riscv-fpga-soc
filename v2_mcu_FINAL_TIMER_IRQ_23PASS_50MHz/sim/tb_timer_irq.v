`timescale 1ns/1ps
module tb_timer_irq;
reg sys_clk=0, sys_rst_n=0, uart_rx_pin=1;
wire [31:0] pc, inst, alu_result, wb_data;
wire [7:0] gpio_out;
wire uart_tx_pin;
integer checks=0, errors=0, cycles=0, entries=0, returns=0;
reg [31:0] saved_pc;
reg [7:0] old_gpio;
reg last_in_handler=0;
cpu_top #(.ROM_PROGRAM(5), .TIMER_DEMO_PERIOD(32'd120),
    .UART_CLKS_PER_BIT(16)) dut(
    .sys_clk(sys_clk), .sys_rst_n(sys_rst_n), .pc(pc), .inst(inst),
    .alu_result(alu_result), .wb_data(wb_data), .gpio_in(8'd0),
    .gpio_out(gpio_out), .uart_tx_pin(uart_tx_pin), .uart_rx_pin(uart_rx_pin));
always #5 sys_clk=~sys_clk;
task check;
    input [8*100-1:0] name;
    input condition;
    begin
        checks=checks+1;
        if(condition!==1'b1) begin errors=errors+1;$display("[FAIL] %0s",name);end
        else $display("[PASS] %0s",name);
    end
endtask

initial begin
    #2;
    check("reset disables interrupt",dut.irq_csrs_inst.irq_request===0 &&
          dut.irq_csrs_inst.mepc===0 && dut.irq_csrs_inst.mcause===0);
    @(negedge sys_clk);sys_rst_n=1;
    // Observe two complete traps while the CPU otherwise polls UART RX.
    while(returns<2 && cycles<3500) begin
        @(posedge sys_clk);#1;cycles=cycles+1;
        if(pc==32'h200 && !last_in_handler) begin
            entries=entries+1;
            saved_pc=dut.irq_csrs_inst.mepc;
            old_gpio=gpio_out;
            check("interrupt cause is platform-local 16",
                  dut.irq_csrs_inst.mcause===32'h80000010);
            check("trap saves pending instruction address",
                  saved_pc>=32'h118 && saved_pc<=32'h180 && saved_pc[1:0]==0);
            check("global interrupt masked in handler",
                  dut.irq_csrs_inst.mie_global===0);
            last_in_handler=1;
        end
        if(last_in_handler && pc==saved_pc &&
           dut.irq_csrs_inst.mie_global===1) begin
            returns=returns+1;
            check("MRET resumes at saved PC",pc===saved_pc);
            check("handler toggles GPIO",gpio_out===(old_gpio ^ 8'd1));
            check("handler clears sticky Timer request",dut.timer_inst.expired===0);
            last_in_handler=0;
        end
    end
    check("two timer interrupts serviced",entries>=2 && returns>=2);
    #2;sys_rst_n=0;#1;
    check("reset clears interrupt and GPIO",dut.irq_csrs_inst.irq_request===0 &&
          dut.irq_csrs_inst.mepc===0 && dut.timer_inst.expired===0 &&
          gpio_out===0);
    if(errors==0) $display("tb_timer_irq PASS: checks=%0d",checks);
    else $display("tb_timer_irq FAIL: checks=%0d errors=%0d",checks,errors);
    $finish;
end
initial begin #40000;errors=errors+1;$display("tb_timer_irq FAIL: timeout");$finish;end
endmodule
