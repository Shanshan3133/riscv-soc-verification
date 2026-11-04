# 自研 RV32I SoC + 自动化验证平台

**FPGA-validated RV32I SoC with Python hardware test automation.** A custom multicycle Verilog/SystemVerilog processor, synchronous block RAM, a Wishbone-style bus, UART/GPIO peripherals, and a CRC-protected serial debug bridge. Implemented on a Digilent Basys3 using Vivado 2025.2.

**Measured hardware results:** 141/141 differential test programs and 7/7 bring-up checks passed; 10 MHz SoC clock, setup slack 79.920 ns, hold slack 0.072 ns, and zero final DRC violations. Uses 3,083 LUTs, 1,871 flip-flops, and 8 RAMB36 blocks. Methodology warnings and untested external interfaces are documented in the [hardware report](reports/hardware/SUMMARY.md). These are FPGA validation results, not ASIC post-silicon or official ISA certification.

包含自写 RTL、仿真、Python 主机工具、固件、FPGA 构建脚本和文档。已完成 Basys3 实物 JTAG 下载、串口通信、141/141 CPU 差分回归和 7 项附加检查；Vivado 时序通过，最终 DRC 无违规。外部仪器采集尚未执行。详见 [实物报告](reports/hardware/SUMMARY.md) 和 [复现步骤](docs/basys3-bringup.md)。

## 一键运行

在本目录运行（Python 3.12+）：

```powershell
# Windows 没有 Icarus 时，先安装到项目 .tools，不改系统 PATH：
python scripts/setup_windows.py
python scripts/test_all.py
```

已有 Icarus Verilog 12/13 时直接运行 test_all.py。可用 IVERILOG 环境变量指定工具绝对路径。Linux 安装 Python 和 Icarus 后使用同一入口。

验证包含 122 次 CPU RTL 差分仿真、外设/串口调试桥/示例固件集成测试，以及 Python 客户端重放测试。查看 [HTML 报告](reports/regression.html)、[JSON 报告](reports/regression.json)、[集成结果](reports/integration/summary.json)。更大回归：`python verification/run.py --seeds 100`。

## 功能

- 多周期 RV32I：整数算术/逻辑、移位、分支、跳转、字节/半字/字访存、FENCE、ECALL/EBREAK；独立 Python 模型逐条对比退休结果。
- Wishbone 风格单事务总线、同步 16 KiB 程序 BRAM + 16 KiB 数据 BRAM、字节使能和错误响应。
- 自研 UART 8N1：TX busy、单字节 RX、溢出/帧错误、可配置 divider；GPIO 输入与部分写。
- 独立 UART 调试桥：CRC16、加载/读写内存、寄存器快照、单步、运行预算、停止和复位。
- Python 串口客户端、真实板级批量回归执行器、SCPI 连接与 Saleae 自动采集适配器。
- Arty A7/Basys3 XDC、10 MHz MMCM 板级顶层、Vivado 构建/检查脚本、Yosys Artix-7 综合脚本和 GitHub Actions 配置。
- 无需交叉编译器的固件：UART 输出 `RV32I OK`、GPIO=15、EBREAK 停止，附等价汇编。

这是无特权、stop-on-trap 的教学/验证 SoC。不实现 CSR、中断、M-mode、乘除法、压缩指令、缓存、DDR 或 OS；不宣称通过官方 ISA 合规认证。未套用现成 CPU 核心。

## 阅读顺序

1. [架构与地址映射](docs/architecture.md)
2. [验证与覆盖说明](docs/verification.md)
3. [调试协议](docs/protocol.md)
4. [实际缺陷记录](docs/bug-log.md)
5. [构建和接线](docs/board.md)
6. [硬件清单](docs/hardware.md)

目录：rtl/、verification/、firmware/、host/、constraints/、scripts/、reports/。

Vivado：`vivado -mode batch -source scripts/build_vivado.tcl -tclargs arty35`（或 arty100、basys3）。顶层选择 board_top。

参考：[RV32I 规范](https://docs.riscv.org/reference/isa/unpriv/rv32.html)、[Digilent XDC](https://github.com/Digilent/digilent-xdc)、[Saleae Automation API](https://docs.saleae.com/automation)。
