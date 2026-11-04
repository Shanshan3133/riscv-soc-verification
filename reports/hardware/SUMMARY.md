# Basys3 实物验证 — 2026-10-28

- Vivado 2025.2 JTAG 下载成功，FPGA DONE=1；只配置易失 FPGA，未写 Flash。
- COM4 / 115200 / 8N1，SoC 时钟 10 MHz。
- 实物 CPU 差分回归：**141/141 PASS**（41 项定向测试 + 100 组随机程序）。
- 对比最终 32 个寄存器、PC、停止原因以及程序访问过的数据内存。板上没有采集逐指令退休轨迹。
- 附加检查：坏 CRC、坏尾标、保留字段非零、截断帧超时恢复；20 次软件复位保留 BRAM 并清除寄存器；单步执行后运行至 EBREAK；GPIO 输出寄存器模式读回。共 7 项通过。
- 最终 GPIO=15；用户已确认 LD0–LD3 四个 LED 全亮（人工观察）。
- Vivado 时序：WNS=79.920 ns、WHS=0.072 ns、TNS/THS=0，内部未约束端点为 0。
- 最终 DRC：0 项违规。LUT=3083、FF=1871、RAMB36=8。
- Methodology 仍提示复位同步器由 LUT 驱动异步置位，以及 BRAM 输出寄存器未合并；未将这些提示隐藏或降级。外部异步串口/GPIO端口设置 false path，静态时序不证明其引脚级波形质量。

## 本次修复

按 Digilent Master XDC 补充 Basys3 配置电压设置；在复位同步器之后增加同步寄存器，消除 BRAM 异步控制 DRC 警告。修复后重新通过 RTL UART/外设/固件集成和 Python 协议测试，完成综合、布局布线及 bitstream 生成。

## 证据

- `board-regression.json`：逐项 PASS/FAIL、耗时和程序校验值。
- `bringup.json`：协议恢复、软件复位和 GPIO 寄存器检查。
- `program-vivado.log`：实际板卡 JTAG 下载与 DONE 状态。
- `manifest.json`：板卡信息、烧录文件和源文件校验值。
- `timing.rpt`、`utilization.rpt`、`drc.rpt`、`cdc.rpt`：本次实现报告。

## 尚未验证

外设 UART 引脚级回环、外部逻辑分析仪/示波器采集、ILA、按键物理复位、断电重启、温压变化和长时间可靠性测试。不是官方 ISA 合规认证，也不能将 FPGA 测试称为实际 ASIC post-silicon 验证。

复现命令见 `docs/basys3-bringup.md`。

