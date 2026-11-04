# 验证说明

## 运行全部非硬件回归

项目根目录运行 `python scripts/test_all.py`，依次生成 smoke 镜像、运行 CPU 差分测试、运行 SoC 集成测试、重放 RTL 响应测试 Python 客户端。依赖 Python 3.12+ 和 Icarus Verilog 12/13；不依赖 FPGA、RISC-V GCC 或 pytest。

Windows 可运行 `python scripts/setup_windows.py` 安装到项目 `.tools`，不修改系统 PATH。下载来自 MSYS2 官方包仓库，包版本与 SHA256 保存在 scripts/windows-tools.json。若安装位置不同，设置 IVERILOG 环境变量为 iverilog.exe 的绝对路径。

Linux：安装 Python 与 Icarus 后运行同一入口。GitHub Actions 工作流可在此目录作为仓库根目录时使用；当前没有发布远程仓库或执行远程 CI。

## CPU 差分

Python 模型按字节建模内存，RTL 测试台按 32 位字及 byte enable 建模，减少同构实现掩盖错误的风险。每条退休记录比较 PC、编码、rd、写回值；访存额外比较地址和数据。再比较全部 32 个寄存器、停止 PC 与原因。固定随机种子保证复现。

默认 20 个随机程序，每个 150 条随机指令；加定向算术、字节/半字访问、分支、跳转和错误路径用例。每个用例分别运行无额外等待和 0–3 周期随机等待。测试台断言请求在等待时保持稳定。记录实际等待周期，而不只记录配置。

覆盖门槛：38 类正常退休指令均执行；ECALL/EBREAK 被识别并停止；六类分支各有 taken/not-taken；停止原因 1–8 均命中；至少观察到一个等待周期。覆盖指令类别不等于穷尽所有操作数、RTL 行/翻转覆盖或官方 ISA 合规认证。

输出：reports/regression.json、regression.html、cases/ 中逐用例镜像和 trace、smoke.vcd 波形。报告包含源码/镜像 SHA256、工具版本、周期数与退休数。

## 集成

- tb_peripherals：同步 BRAM、部分写、GPIO、无效地址、重复应答保护、UART TX/RX、busy、overflow、framing error、W1C。
- tb_debug：真正模拟 8N1 UART 电平，与 Python 生成的帧交互；检查 HALT、RESET、READ_REG、READ_MEM、WRITE_MEM、STEP、RUN、STATUS、坏 CRC、参数错误、总线错误和运行超时。
- tb_demo：CPU 从程序 BRAM 执行 firmware/demo.hex，经自研 UART 发出 `RV32I OK\r\n`，GPIO=15，最终 EBREAK。
- test_host：CRC 已知向量、逐字节破损、基于实际 RTL 应答的客户端重放，包含短读、输入噪声与错误响应。

仿真加快 UART divider 为 16；板级时钟为 10 MHz、divider 为 87。仿真验证时序算法和功能，物理时钟误差、线路质量及真实串口驱动需板级测试。

## 综合与时序

`yosys -s scripts/synth_yosys.ys -l reports/synthesis-yosys.log` 或 `yowasp-yosys` 可做 Artix-7 综合与结构检查。输出网表并不包含布局布线后的时序结论。

Vivado：`vivado -mode batch -source scripts/build_vivado.tcl -tclargs arty35`。可选 arty100、basys3。脚本输出资源、setup/hold、DRC、CDC 报告；负裕量或 DRC 错误时不生成 bitstream。未安装 Vivado 的环境无法验证该工具的实际执行结果。

## 已准备但未接实物的工具

host/board_regression.py 实现真实串口批量加载、CPU 状态/寄存器/内存比较，并保存板卡与 bitstream 摘要；必须显式给出 COM 口、板卡名与 bitstream 路径。host/instruments.py 提供 PyVISA/SCPI 连接和 Saleae Logic 2 自动采集适配器。具体示波器的触发、波形命令需按型号补充；未虚构通用 SCPI 命令。
