# riscv-fpga-soc

基于 FPGA 的 RISC-V 指令子集微控制器 SoC，使用 Cyclone IV E EP4CE10F17C8 和 50 MHz 板载时钟。

当前最终版位于 **`v2_mcu/`**，包含 GPIO、Timer、双向 UART、本地 Timer 中断，以及 CSRRW、CSRRS、MRET 的有限实现。

| 目录 | 内容 |
| --- | --- |
| `v2_mcu/` | 当前工作版，默认 `ROM_PROGRAM=5`，Timer 中断与双向 UART |
| `v1_cpu/` | 基础 CPU 第一版 |
| `v2_mcu_UART_RX_21PASS_50MHz/` | UART RX 阶段备份 |
| `v2_mcu_FINAL_TIMER_IRQ_23PASS_50MHz/` | 最终工程备份；其中嵌套的 `v2_mcu/` 是重复副本 |
| `doc/` | 设计规格说明书、模块设计与验证记录及历史资料 |

## 复现入口

- Quartus：打开 `v2_mcu/Qproject/MCU.qpf`，顶层为 `fpga_top`。
- ModelSim：运行 `v2_mcu/sim/run_all.do`；脚本内项目根目录需匹配本机路径。
- 上板：使用 `v2_mcu/Qproject/output_files/MCU.sof`。
- 串口：115200 baud、8N1。启动后输出 `OK` 换行；ASCII `0`/`1` 改变 D7，周期 Timer 中断随后继续翻转 D7。D6 为运行心跳。

## 验证与文档

本机 ModelSim 10.5 重新运行 **23 项测试，全部通过**。最终验证摘要见 [summary.txt](v2_mcu/verification/summary.txt)，完整日志见 [final_regression.log](v2_mcu/verification/final_regression.log)。

既有 Quartus 报告确认已约束内部路径满足 50 MHz；最差 setup 为 +0.712 ns，hold 为 +0.179 ns。外部 I/O 仍有未约束路径。上板双向 UART 与 Timer 中断共存的结果来自项目中已确认的实测记录。

- [设计规格说明书](<doc/【设计规格说明书】基于 FPGA 的 RISC-V 微控制器 SoC 设计规格说明书（RV32I 子集） (2).docx>)
- [模块设计与验证记录](doc/模块设计与验证记录.docx)

本次上传按完整目录快照保存各阶段版本、文档、验证记录、SOF、编译产物和仿真库。备份目录中的早期 README 和日志保留原阶段内容，当前状态以 `v2_mcu/verification/summary.txt` 及上述更新后的 Word 文档为准。
