# ModelSim Transcript: do {D:/02GitHub/01riscv-fpga-soc/v2_mcu/sim/run_rx.do}
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
vsim -onfinish stop -voptargs=+acc -t 1ps gpio_work.tb_cpu_uart_rx
add wave /tb_cpu_uart_rx/sys_clk /tb_cpu_uart_rx/sys_rst_n
add wave /tb_cpu_uart_rx/uart_rx_pin /tb_cpu_uart_rx/uart_tx_pin
add wave -radix hexadecimal /tb_cpu_uart_rx/pc /tb_cpu_uart_rx/gpio_out
add wave /tb_cpu_uart_rx/dut/uart_rx_inst/valid /tb_cpu_uart_rx/dut/uart_rx_inst/state
add wave -radix hexadecimal /tb_cpu_uart_rx/dut/uart_rx_inst/rx_data
run -all
wave zoom full
