# CPU 50 MHz 时序修复候选版

本包基于上传的 111.zip 修改。已运行 RTL 仿真；未运行 Quartus 布局布线，因此 50 MHz 的实际 setup/hold 裕量仍需重新编译确认。

## 修改原因和行为

原报告最差路径从 PC 寄存器到数据 RAM 的写使能寄存器，setup slack 为 -1.329 ns；PC 到寄存器堆也有负裕量。
原实现直接用组合 ROM 输出进行译码和执行，取指、译码、读取操作数、ALU、地址检查/写回挤在一个周期内。

cpu_top.v 增加 inst_reg 和 execute 状态，把组合 ROM 路径截在指令寄存器处：

| 指令 | 第 1 拍 | 第 2 拍 | 第 3 拍 |
| --- | --- | --- | --- |
| ADD/SUB/AND/OR/XOR/ADDI/LUI | FETCH：锁存指令，PC保持 | EXECUTE：写回，PC更新 | — |
| SW | FETCH：锁存指令，PC保持 | EXECUTE：写RAM，PC更新 | — |
| BEQ/BNE/JAL/JALR | FETCH：锁存指令，PC保持 | EXECUTE：按当前PC计算跳转和返回地址，提交 | — |
| LW | FETCH：锁存指令，PC保持 | EXECUTE：RAM采样地址，PC保持 | LOAD_WB：写回RAM输出，PC更新 |

FETCH期间禁止寄存器写入和RAM写入，防止上一条指令被重复执行。指令寄存器在EXECUTE/LOAD_WB期间保持。
PC在指令提交前保持，因此分支基地址、JAL/JALR的PC+4返回地址不需要另存一份PC。
这是多周期CPU，不是流水线CPU。普通指令2拍，LW3拍；时钟仍为50 MHz。
调试端口 inst 现在表示锁存后的当前指令；FETCH期间可能显示上一条指令，这是正常的。

## 文件替换

将包内 rtl/ 和 sim/ 中的文件合并到现有项目对应目录，选择覆盖同名文件。
不要删除或整体重建你现有的 rtl/、sim/ 目录，本包只包含以下5个改动/新增文件：

- rtl/cpu_top.v：增加取指/执行控制和指令寄存器。
- sim/tb_cpu_top.v：适配2拍普通指令和3拍LW，检查FETCH写入屏蔽与完成循环。
- sim/tb_instr_rom.v：0x50的预期值修正为jal x0,0（0000006F），ROM程序本身未修改。
- sim/tb_cpu_corner.v：新增补充回归；测试中使用force注入指令，仅用于仿真。
- sim/tb_fpga_top.v：新增板级回归；仅在测试实例中缩短心跳周期。

无需更改 cpu_top 的外部端口、fpga_top、引脚绑定或1 KiB同步M9K RAM。
保留 fpga_top 中 LED_ACTIVE_LOW=1，顶层继续使用 fpga_top。

## 已完成的仿真

Icarus Verilog 11.0，Verilog-2001模式；$stop作为测试结束处理。

| 测试 | 结果 |
| --- | --- |
| tb_cpu_top | PASS，88项检查 |
| tb_cpu_corner | PASS，151项检查 |
| tb_fpga_top | PASS，44项检查 |
| tb_data_ram | PASS，12项检查 |
| tb_instr_rom | PASS，25项检查 |
| tb_control_unit | PASS，19项检查 |
| tb_decoder | PASS，57项检查 |
| tb_imm_gen | PASS，101项检查 |
| tb_pc_reg | PASS，11项检查 |
| tb_regsfile | PASS，测试未打印检查总数 |
| tb_alu | 8个边界检查无FAIL，输出Boundary tests completed |

补充回归覆盖：后继指令依赖、SW不得在FETCH重复写入、RAM最后一个字、连续LW、LW的rd=rs1、x0不可写、非法地址不别名写入、非法LW返回0、非法指令不写入、JALR清除bit0、分支不跳转/向后跳转、LW等待中复位、取指后SW被复位取消，以及LED极性和复位同步。

## 在 ModelSim 中

重新编译RTL和修改后的测试文件后，运行 tb_cpu_top（run 1 us 足够），应显示 tb_cpu_top PASS: checks=88。
可再运行 tb_cpu_corner 和 tb_fpga_top（各 run 5 us 足够），应分别显示 checks=151 和 checks=44。
运行新版 tb_instr_rom 应显示 checks=25。出现$stop是正常结束；有FAIL则先停止上板。

## 在 Quartus 中

1. 顶层保持 fpga_top，确认工程实际使用新 cpu_top.v。
2. 保留 Qproject/fpga_top.sdc 中的50 MHz约束：

```tcl
create_clock -name sys_clk -period 20.000 [get_ports {sys_clk}]
derive_clock_uncertainty
```

3. 保留 MCU.qsf 中的引用：set_global_assignment -name SDC_FILE fpga_top.sdc。
4. 执行完整编译。SDC File List中应读入该文件，Clocks中sys_clk周期应为20 ns。
5. 查看各模型的Setup/Hold及Multicorner Timing Analysis Summary；同时检查Recovery/Removal/Minimum Pulse Width是否有负裕量。
6. 把新的Setup/Hold结果及任何失败路径发回核对。若仍为负裕量，需要根据新瓶颈继续修改。
7. 时序通过后直接下载新生成的MCU.sof：D6闪烁、D7常亮，按住RESET时两灯熄灭。

## 时序通过后保存Git

在项目根目录PowerShell执行：

```powershell
git add rtl/cpu_top.v sim/tb_cpu_top.v sim/tb_instr_rom.v sim/tb_cpu_corner.v sim/tb_fpga_top.v Qproject/fpga_top.sdc Qproject/MCU.qsf
git commit -m "增加指令锁存与分周期执行并保存50MHz时序约束"
git status
```

最后一条应显示working tree clean。只有通过新的Quartus报告，才可以把这版标记为50 MHz时序通过。
