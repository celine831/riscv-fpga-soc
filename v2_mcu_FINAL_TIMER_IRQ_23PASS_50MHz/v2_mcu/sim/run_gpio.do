# Compile all files and open CPU+GPIO waveforms.
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
vsim -onfinish stop -voptargs=+acc -t 1ps gpio_work.tb_cpu_gpio
add wave /tb_cpu_gpio/sys_clk /tb_cpu_gpio/sys_rst_n
add wave -radix hexadecimal /tb_cpu_gpio/pc /tb_cpu_gpio/inst
add wave -radix hexadecimal /tb_cpu_gpio/gpio_in /tb_cpu_gpio/gpio_out
add wave /tb_cpu_gpio/dut/load_wait /tb_cpu_gpio/dut/load_req
add wave /tb_cpu_gpio/dut/ram_sel /tb_cpu_gpio/dut/gpio_sel
add wave -radix hexadecimal /tb_cpu_gpio/dut/alu_result
add wave -radix hexadecimal /tb_cpu_gpio/dut/mem_rdata /tb_cpu_gpio/wb_data
run -all
wave zoom full
