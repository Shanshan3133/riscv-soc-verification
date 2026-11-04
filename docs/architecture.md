# 架构 v1

## CPU

32 位 PC 和 32 个整数寄存器；x0 恒为零、复位 PC=0、上电停止。多周期状态机：BOUNDARY → FETCH → EXEC → [MEM] → COMMIT → BOUNDARY。所有访存完成后才退休下一指令，FENCE 满足本机单主设备顺序要求。

RV32I 的 38 类正常退休指令全部实现；ECALL/EBREAK 与错误条件进入可观测停止状态。没有 CSR、中断和特权态。指令地址必须 4 字节对齐，字/半字访存要求自然对齐。JALR 清除目标 bit0；bit1 非零时停止。非法编码或错误访存不得写回寄存器。

CPU 内嵌寄存器数组和第三个只读 debug 端口；rtl/core/regfile.sv 是初始骨架保留的独立两读一写模块，主核心不实例化它。

## 地址和外设

| 地址 | 用途 |
|---|---|
| 0x00000000–0x00003FFF | 16 KiB 程序 BRAM，可由调试主机加载 |
| 0x10000000–0x10003FFF | 16 KiB 数据 BRAM |
| 0x20000000–0x200000FF | UART，仅 +0/+4/+8/+12 有效 |
| 0x20000100–0x200001FF | GPIO，仅 +0/+4 有效 |

存储器 little endian；BRAM 初始程序为 EBREAK、数据为零。PROG_HEX 可覆盖程序。RESET 不清除 BRAM。sel 决定写入字节。外设寄存器地址需 4 字节对齐。未实现执行权限保护。

UART +0 TXDATA：发送低字节，busy 时写返回 err。+4 RXDATA：读清 valid，写返回 err。+8 STATUS：bit0 TX ready、bit1 busy、bit2 RX valid、bit3 overflow、bit4 frame error；写 1 清 bit3/bit4。+12 BAUD_DIV：整字写，最小 4；发送或接收中修改返回 err。RX 满时保留原字节并置 overflow；坏停止位不提交字节。RX 输入两级同步。

GPIO +0 OUTPUT 支持 byte enable；+4 INPUT 只读。板级 SW0–3 两级同步后映射 INPUT[3:0]；LED0–3 对应 OUTPUT[3:0]。

## 总线和调试

自定义 Wishbone 风格，未宣称标准合规。32 位字节地址/数据、4 位 sel；请求 cyc/stb/we/addr/wdata/sel；响应 ack/err/rdata。一次只允许一笔未完成事务。等待期间请求保持稳定，ack/err 互斥。fabric 产生单次应答，持续请求不重复执行；deassert 后才允许下次请求。未映射地址返回 err。

BRAM 使用独立同步读端口，外设应答另存寄存器，便于真实块 RAM 推断。CPU 停止且无活动总线请求时调试桥获得总线所有权。命令严格串行，RUN 期间额外输入丢弃。具体帧格式和停止原因见 protocol.md。

## 时钟与接口

board_top 使用 Artix-7 MMCM 将板载 100 MHz 转为 10 MHz，经 BUFG 分配；锁定前保持复位，复位释放同步。UART divider=87，约 114943 baud。

fpga_top 是可仿真的逻辑顶层，其 clk100 端口名沿用骨架；board_top 实际传入 10 MHz。综合/下载选择 board_top。USB-UART 专供 debug，自研 UART 走独立 Pmod 引脚。

observe[0..5] 分别是 bus_req、bus_ack、bus_we、retire_valid、halted、reason_nonzero。完整内部地址/数据适合由 Vivado ILA 抓取。retirement 接口提供 PC、编码、rd/写回值和访存地址/数据。

该项目实现 post-silicon 风格验证流程，没有进行 ASIC 流片。功能覆盖不等于 RTL 行/翻转覆盖或官方 ISA 合规认证。
