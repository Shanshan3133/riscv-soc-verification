# 实际仿真缺陷记录

## SRA 的符号位填充丢失

发现方式：独立 Python 模型逐条对比 RTL 的 retirement trace。

`alu_edges` 在 PC=0x58：0x80000000 算术右移 31 位，期望 0xFFFFFFFF，实际得到 0x00000001。随机 seed=0 的 PC=0x128 也捕获同类问题。

原因：SystemVerilog 三元表达式同时包含 `$signed(a) >>> shift` 和无符号 `a >> shift`，表达式类型传播使算术右移操作受到无符号上下文影响。

修复：用明确的 if/else 分别计算算术与逻辑右移，避免混合符号类型的三元表达式。定向用例保留负数和 31 位移位边界，随机回归保留固定种子。最终结果见 reports/regression.json。

## RESET 应答引用了旧 PC

串口端到端测试先运行 smoke 到 PC=12，再 RESET，发现应答仍回报 PC=12。复位与应答在同一个时钟边沿通过非阻塞赋值更新，应答读到了复位前 PC。增加 RESET_SETTLE 状态，等 CPU 完成复位后再形成应答；用例核对 PC=0 和 x1=0。

## BRAM 无法综合映射

Yosys Artix-7 综合报告 `no valid mapping found`：程序/数据存储器和外设响应共用 rdata 寄存器，未能提取块 RAM 所需的同步读端口。为两块存储器各提供独立同步读寄存器，将外设应答存入 aux_data，再按 response_target 选择。修复后重新跑 SoC、UART、调试桥和固件集成测试。
