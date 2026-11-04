# 硬件采购清单

## 必需

- 一块 Arty A7（35T 或 100T）或 Basys3。当前首版规模预计 35T 级别足够，最终以综合资源报告为准。推荐新购 Arty A7；已有 Basys3 不需要换。
- 对应板卡的数据 USB 线，确认不是仅充电线。板载 USB-JTAG 和 USB-UART 足以完成下载与专用 debug bridge 通信，无需另购下载器。
- 运行 Vivado 和 Python 的电脑；实践建议 16 GB RAM，32 GB 更舒适，并预留安装和构建空间。
- Pmod 接线用杜邦线、分析仪探头线及共地连接。

## 第二阶段

- 可被 Python 控制的逻辑分析仪，至少 8 个数字通道、支持 3.3 V 信号。当前默认系统时钟 10 MHz，观察单周期事件建议 50–100 MS/s，确认所用通道数下仍支持所需速率；最终采样配置需按设备实际能力确认。
- Saleae Logic 8 可通过 Logic 2 Automation API 接入；它不是 SCPI 仪器。如果已有分析仪或示波器，先确认型号及自动化接口，再决定是否购买。
- 3.3 V USB-TTL 串口模块：用于独立自研 UART 外设的收发和回环测试。不要把 RS-232 电平或 5 V TTL 直接接入 FPGA。
- 可选 Pmod 排针转接/小面包板，便于稳定接线。

## 可后买

带 SCPI/LAN/USB 控制的示波器，适合做边沿、脉宽与电气检查；不属于 CPU 功能验证的必需设备。外部 SPI 器件等第二个外设扩展也可后买。

## 首轮接线

电脑 USB → 开发板（下载 + 调试串口）。自研 UART → Pmod TX/RX → 3.3 V USB-TTL。分析仪 → Pmod 观测信号与 GND。已提供 Arty A7/Basys3 XDC，拿到实物后需核对板卡版本。

来源：
- https://digilent.com/shop/arty-a7-100t-artix-7-fpga-development-board/
- https://digilent.com/shop/basys-3-amd-artix-7-fpga-trainer-board-recommended-for-introductory-users/
- https://www.saleae.com/support/extensions-api/automation-api/saleae-api-and-sdk

未提供实时价格；优先利用已有仪器，避免一次购买全套。
