# ModelSim Transcript: do {D:/02GitHub/01riscv-fpga-soc/v2_mcu/sim/run_uart.do}
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
vsim -onfinish stop -voptargs=+acc -t 1ps gpio_work.tb_cpu_uart
add wave /tb_cpu_uart/sys_clk /tb_cpu_uart/sys_rst_n
add wave -radix hexadecimal /tb_cpu_uart/pc /tb_cpu_uart/inst
add wave /tb_cpu_uart/uart_tx_pin /tb_cpu_uart/dut/uart_inst/busy
add wave -radix hexadecimal /tb_cpu_uart/dut/uart_inst/frame
add wave -radix unsigned /tb_cpu_uart/dut/uart_inst/bits_left /tb_cpu_uart/dut/uart_inst/baud_count
run -all
wave zoom full
