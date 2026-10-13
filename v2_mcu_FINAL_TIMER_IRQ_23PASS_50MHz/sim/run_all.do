# ModelSim Transcript: do {D:/your-project/sim/run_all.do}
# Project root is configured explicitly below.
onerror {abort}
# ModelSim 10.5 macros do not reliably populate [info script].
# Set the actual project root explicitly.
set root {D:/02GitHub/01riscv-fpga-soc/v2_mcu}
if {![file isdirectory [file join $root rtl]] || ![file isdirectory [file join $root sim]]} {
    error "Project root must contain rtl and sim: $root"
}
cd $root
set libdir [file join $root modelsim_gpio_work]
if {![file isdirectory $libdir]} {vlib $libdir}
vmap gpio_work $libdir
set sources [concat [glob [file join $root rtl *.v]] [glob [file join $root sim *.v]]]
eval vlog -vlog01compat -work gpio_work $sources
set tests {tb_alu tb_regsfile tb_decoder tb_imm_gen tb_control_unit tb_pc_reg tb_instr_rom tb_data_ram tb_cpu_top tb_gpio tb_cpu_gpio tb_fpga_top tb_timer tb_cpu_timer tb_fpga_timer tb_uart_tx tb_cpu_uart tb_fpga_uart tb_uart_rx tb_cpu_uart_rx tb_fpga_uart_rx tb_irq_csrs tb_timer_irq}
set failed {}
foreach top $tests {
    puts "Running $top"
    vsim -onfinish stop -voptargs=+acc -t 1ps gpio_work.$top
    run -all
    set error_count [examine -radix decimal /$top/errors]
    if {$error_count != 0} {lappend failed $top}
    quit -sim
}
if {[llength $failed] == 0} {
    puts "ALL 23 TESTBENCHES PASSED"
} else {
    error "TESTBENCHES FAILED: $failed"
}
