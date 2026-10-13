# ModelSim Transcript: do {D:/02GitHub/01riscv-fpga-soc/v2_mcu/sim/run_timer.do}
onerror {abort}
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
vsim -onfinish stop -voptargs=+acc -t 1ps gpio_work.tb_cpu_timer
add wave /tb_cpu_timer/sys_clk /tb_cpu_timer/sys_rst_n
add wave -radix hexadecimal /tb_cpu_timer/pc /tb_cpu_timer/inst
add wave -radix hexadecimal /tb_cpu_timer/gpio_out
add wave /tb_cpu_timer/dut/timer_inst/enable /tb_cpu_timer/dut/timer_inst/expired
add wave -radix unsigned /tb_cpu_timer/dut/timer_inst/load_value /tb_cpu_timer/dut/timer_inst/count_value
add wave -radix hexadecimal /tb_cpu_timer/dut/timer_inst/rdata
run -all
wave zoom full
