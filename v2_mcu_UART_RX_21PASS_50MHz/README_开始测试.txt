RV32I CPU + GPIO 完整源码与验证包
================================

本包基于你上传的111.zip，完成GPIO接入、地址译码、
CPU外设程序验证和FPGA顶层LED连接。本阶段不包含Timer/UART。

一、放文件
1. 先备份现有rtl和sim文件夹。
2. 将包内rtl、sim复制到你的工程根目录，同名文件使用本包版本替换。
3. 不要让两个不同路径的同名模块同时进入工程。
4. rtl中全部11个.v文件用于设计；sim中12个tb_*.v文件仅用于仿真。

二、先跑ModelSim测试（不需要先综合Quartus）
1. 打开ModelSim，在Transcript输入以下命令。
2. 路径换成你的实际工程路径，使用正斜杠。

do {D:/02GitHub/01riscv-fpga-soc/sim/run_all.do}

脚本自动创建独立的gpio_work仿真库，编译rtl和sim全部.v文件，
依次运行12个自检TB。每个TB结束后脚本会检查errors计数。
成功时最后显示：ALL 12 TESTBENCHES PASSED
如果此前正运行另一场仿真，先输入quit -sim，再运行脚本。

想看CPU读写GPIO的波形，运行：
do {D:/02GitHub/01riscv-fpga-soc/sim/run_gpio.do}

这里执行两轮程序，分别使用输入0xA6和0x3C。
每轮最终PC停在0xA8、GPIO输出为1；中间输出经历5、0xAA、1。

三、Quartus中添加文件
1. Project > Add/Remove Files in Project。
2. 添加rtl文件夹中的全部11个.v文件，清理原来指向其他目录的重复条目。
3. 不要添加sim中的Testbench到综合文件列表。
4. 如果准备编译上板，顶层设置为fpga_top。
5. fpga_top保持原来的sys_clk、sys_rst_n、led_run、led_done四个端口。
   如果你此前已经分配了这些引脚，可以沿用；否则仍需根据板卡分配。
6. LED_ACTIVE_LOW默认1：适合低电平点亮的LED。
   若板卡LED高电平点亮，把它改为0。
7. HEARTBEAT_BIT默认25，按50MHz板载时钟设置。

上板预期：led_run为独立心跳；led_done由CPU通过SW写GPIO bit0控制。
程序完成后第二个LED点亮。中间的GPIO变化太快，肉眼通常看不到。
本顶层GPIO输入接0；真实按键引脚接入留待确认板卡引脚后完成。

四、两套ROM程序
instr_rom参数PROGRAM=0：原CPU测试程序，PC停在0x50。
instr_rom参数PROGRAM=1：先运行原程序，再运行GPIO扩展，PC停在0xA8。
cpu_top参数ROM_PROGRAM默认0，原tb_cpu_top因此继续运行原程序。
tb_cpu_gpio和fpga_top显式选择ROM_PROGRAM=1。
GPIO扩展指令逐条说明见gpio_program.txt。

五、地址与时序
RAM：0x00000000~0x000003FF（1KiB），LW/SW要求4字节对齐。
GPIO输出：0x10000000，读写，保存写入数据低8位。
GPIO输入：0x10000004，只读，经过两级同步。
其他GPIO地址、未映射地址、未对齐读取返回0；无效写入忽略。
LW第一拍保持PC并发读请求，第二拍写回并前进PC。
保存读目标load_target，与RAM/GPIO同步返回的数据对齐。
GPIO两级同步不等于按键消抖，也不保证多位总线同时改变时的一致性。

六、关键文件
rtl/gpio.v：GPIO寄存器、输入同步、同步读。
rtl/cpu_top.v：RAM/GPIO地址译码、读目标保存、读数据选择。
rtl/instr_rom.v：保留原程序并新增GPIO程序。
rtl/fpga_top.v：GPIO输出连接第二个LED。
sim/tb_gpio.v：GPIO模块32项自检。
sim/tb_cpu_gpio.v：CPU+GPIO两轮程序188项自检。
sim/tb_fpga_top.v：复位同步、LED极性、GPIO控制113项自检。
sim/run_all.do：全部12个Testbench自动回归。
sim/run_gpio.do：CPU+GPIO波形。

七、已完成的验证
本包全部12个TB通过Icarus Verilog的Verilog-2001编译和仿真。
记录在verification/summary.txt及各TB日志。
ModelSim脚本已提供，尚未在本环境的ModelSim中运行。
尚未在你的Quartus工程中综合、进行时序分析或实际下载板卡。
