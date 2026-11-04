# 调试协议 v1

固定 16 字节帧，8N1，board_top 使用 10 MHz/87≈114943 baud；独立 UART 默认 divider=868 适配 100 MHz。所有多字节字段小端。

| 字节 | 内容 |
|---|---|
| 0 | A5 |
| 1 | 命令；响应为命令 OR 80 |
| 2 | 序号，响应原样返回 |
| 3 | 请求必须为 0；响应状态 |
| 4–7 | 请求地址；响应当前 PC |
| 8–11 | 请求/响应数据 |
| 12–13 | 前 12 字节的 CRC16-CCITT-FALSE：poly=1021、init=FFFF、xorout=0 |
| 14–15 | 5A C3 |

状态：0 成功、1 参数/命令错误、2 CPU 状态不允许、3 总线错误、4 RUN 超时。CRC/尾标错误帧直接丢弃；不允许修改 SoC 状态。部分帧空闲超过 FRAME_TIMEOUT 个时钟后丢弃。

命令：1 HALT；2 RESET；3 READ_REG（data=0..31）；4 READ_MEM（address，返回 word）；5 WRITE_MEM（address/data，整字写）；6 STEP；7 RUN（data=最大运行周期，非零）；8 STATUS。

RESET 复位 CPU、GPIO 和外设，不清除 BRAM；程序和数据可由主机整字覆盖。CPU 上电停止，PC=0。READ/WRITE/STEP 需 CPU 已停止。EBREAK/异常停止后需要 RESET，不能直接跨过陷阱继续执行。STEP 成功后原因 9。RUN 返回 halt_reason，超时时在指令边界停止并返回状态 4；主机应检查错误响应。

STATUS 返回 data bit0=halted、bits4:1=halt_reason。READ_REG/READ_MEM 返回读取值。HALT/RUN/STEP 返回停止原因。停止原因：0 reset、1 EBREAK、2 ECALL、3 illegal、4 instruction misalignment、5 load misalignment、6 store misalignment、7 fetch access、8 data access、9 manual/step halt。

请求严格串行：发送下一帧前必须读完上一响应。桥在执行命令时丢弃额外输入字节；RUN 期间不能再发 HALT，应采用适当周期预算。CRC 检测传输错误，不是认证机制。当前总线从设备保证应答；扩展外设时必须增加总线超时。

主机入口：`python host/client.py --port COM5 --image firmware/smoke.hex`。仅在板卡接入且 bitstream 下载后运行。主机协议与 RTL 的端到端串口行为在仿真中验证，不代表实物已验证。
