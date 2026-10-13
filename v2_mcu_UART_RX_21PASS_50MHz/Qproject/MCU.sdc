# 野火征途 Pro 板载晶振：50 MHz，周期 20 ns。
# 放在 Quartus 新工程 MCU.qsf 所在目录；MCU.qsf 已引用 MCU.sdc。
create_clock -name sys_clk -period 20.000 [get_ports {sys_clk}]
derive_clock_uncertainty
