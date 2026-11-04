# Basys3 实物复现步骤

本次连接：板载 USB-JTAG + USB-UART，串口 COM4，115200 baud，8N1。只通过 JTAG 配置 FPGA，未写入配置 Flash；断电后需重新下载。

## 本次修复

- `constraints/basys3.xdc` 根据 Digilent 官方 Master XDC 设置 `CONFIG_VOLTAGE=3.3`、`CFGBVS=VCCO`。
- `fpga_top.sv` 在异步置位/同步释放的复位同步器之后增加一级无异步控制的同步寄存器，避免异步复位信号直接影响 BRAM 控制。时钟未锁定时仍由 MMCM LOCKED 路径请求复位；时钟恢复后系统保持复位再释放。
- 重新跑 UART 调试桥、外设、示例程序的 RTL 集成测试和 Python 协议测试。
- Vivado 最终 DRC 无违规；时序通过。Methodology 仍有 LUT 驱动复位同步器异步置位，以及 BRAM 未合并输出寄存器的提示，不能把 DRC 为零表述成所有检查完全无警告。

## Windows 命令

在项目根目录打开 PowerShell。将 Vivado 路径和串口替换为本机实际值。

```powershell
$vivado = 'C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat'
& $vivado -mode batch -source scripts/build_vivado.tcl -tclargs basys3
& $vivado -mode batch -source scripts/program_basys3.tcl -tclargs build/basys3/riscv_soc.bit 210183BE6AA5

# pyserial 安装在项目目录，不改系统 Python 环境
python -m pip install --target .tools/python pyserial==3.5
$env:PYTHONPATH = (Join-Path $PWD '.tools/python')
python host/client.py --port COM4
python host/board_regression.py --port COM4 --board Basys3 --bitstream build/basys3/riscv_soc.bit --seeds 100
python host/board_bringup.py --port COM4
```

`program_basys3.tcl` 必须传入当前板卡的实际序列号，且会核对 xc7a35t 器件。关闭串口终端软件以避免 COM4 被占用。一次只能运行一个串口客户端。

回归逐项比较最终寄存器、所访问的数据内存、PC 和停止原因；不提供板上逐指令退休轨迹，也不等同于官方 ISA 合规认证。测试证据保存在 `reports/hardware/`。

`board_bringup.py` 完成后将 GPIO 输出设为 15，供人工核对 LD0–LD3。自动读取 GPIO 寄存器成功不能单独证明 LED 的物理状态。UART 外设的引脚级回环需要额外接线，当前无接线测试不覆盖该路径。

参考：https://github.com/Digilent/digilent-xdc/blob/master/Basys-3-Master.xdc
