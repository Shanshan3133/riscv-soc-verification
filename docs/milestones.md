# 验收状态

已实现并通过本地 RTL 仿真：RV32I 核心和停止原因、同步 BRAM/总线、自研 UART/GPIO、串口调试桥与单步、程序加载、Python 协议工具、示例固件端到端 UART 输出。

已提供：Arty A7/Basys3 XDC、MMCM 时钟顶层、Vivado 综合/时序/DRC/CDC 检查脚本、Yosys 综合入口、GitHub Actions、串口板级回归执行器与仪器适配器。

工具结果以 reports/ 实际日志为准。Basys3 已完成 Vivado 实现、时序、bitstream、实物下载与 CPU 差分回归，详见 reports/hardware/SUMMARY.md；远程 CI 未发布执行；仪器适配器未连接设备。

后续实物验收：核对 PCB/接线 → Vivado 构建且时序/DRC 通过 → 下载 → 调试串口加载 smoke → 核对寄存器 → 批量板级回归 → 独立 UART 回环 → 逻辑分析仪/示波器采集。
