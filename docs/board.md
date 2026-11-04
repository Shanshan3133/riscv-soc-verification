# 构建与接线

当前未进行实物验证。本文件供板卡到货后使用。

## 构建

根目录运行 `vivado -mode batch -source scripts/build_vivado.tcl -tclargs arty35`；也支持 arty100、basys3。顶层 board_top，100 MHz 输入经 MMCM 转 10 MHz，串口约 115200 baud。

build/板卡名 保存资源、setup/hold、DRC、CDC 报告。脚本在负时序裕量或 DRC 错误时不生成 bitstream，不自动下载板卡。XDC 源于 Digilent master 文件，实物需核对 PCB 版本，尤其 Arty A7-100T 映射。

内存默认 EBREAK/零，CPU 上电停止，通过 debug 串口加载程序。无需 DDR 或额外下载器。

## Pmod JA

| 物理针号 | 用途 |
|---|---|
| 1 | 外设 UART TX → USB-TTL RX |
| 2 | 外设 UART RX ← USB-TTL TX |
| 3 / 4 | bus request / acknowledge |
| 7 / 8 | write enable / retirement valid |
| 9 / 10 | halted / reason_nonzero |
| 5 / 11 | GND，共地 |
| 6 / 12 | 3.3 V 电源，勿误接探头信号线 |

UART 使用 3.3 V TTL。板载 USB-UART 连接 debug 客户端；独立 Pmod UART 可回环或接 USB-TTL。Arty BTN0 / Basys3 中心键复位；SW0–3 输入，LED0–3 输出。

10 MHz 下单周期为 100 ns；观察单周期事件建议多通道实际采样率 50–100 MS/s。低速设备先测 UART，或调整 MMCM/baud divider 降低时钟。外部少量观测引脚不能替代完整内部总线检查，完整信号使用 ILA。

## 软件

`python -m pip install -r requirements-hardware.txt`。真实仪器采集还需驱动、VISA backend 或 Logic 2 automation server。

下载后：`python host/client.py --port COM5 --image firmware/demo.hex`。独立 UART 口应看到 RV32I OK。

批量回归：`python host/board_regression.py --port COM5 --board arty35 --bitstream build/arty35/riscv_soc.bit`。工具初始化每个测试涉及的数据字并核对最终状态，报告带 bitstream 摘要。

官方来源：[Arty A7-35](https://github.com/Digilent/digilent-xdc/blob/master/Arty-A7-35-Master.xdc)、[Basys3](https://github.com/Digilent/digilent-xdc/blob/master/Basys-3-Master.xdc)。
