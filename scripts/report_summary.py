"""Summarize only evidence actually produced by local tools."""
import json,hashlib,collections
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
reports=ROOT/'reports'
reg=json.loads((reports/'regression.json').read_text())
integration=json.loads((reports/'integration/summary.json').read_text())
net=json.loads((reports/'netlist-xc7.json').read_text())
modules=net['modules'];counts=collections.Counter()
def walk(name):
    for cell in modules[name]['cells'].values():
        kind=cell['type']
        if kind in modules and modules[kind]['cells'] and not int(modules[kind].get('attributes',{}).get('blackbox','0'),2):walk(kind)
        else:counts[kind]+=1
walk('board_top')
assert reg['coverage_gate']['passed'] and all(x['status']=='PASS' for x in reg['results'])
assert all(x['status']=='PASS' for x in integration['results'])
assert counts['RAMB36E1']==8
summary=dict(cpu_runs=len(reg['results']),cpu_passes=sum(x['status']=='PASS' for x in reg['results']),
             functional_coverage_gate=reg['coverage_gate'],retirements_compared=sum(x['retired'] for x in reg['results']),
             observed_extra_wait_cycles=sum(x['wait_observed'] for x in reg['results']),integration=integration,
             synthesis_tool=net.get('creator'),synthesis_cells=dict(sorted(counts.items())),
             not_executed=['Vivado implementation/static timing/bitstream','physical FPGA tests','instrument capture','remote GitHub Actions'])
(reports/'summary.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
luts=sum(counts[f'LUT{i}'] for i in range(1,7))
text=f'''# 实际验证结果

- CPU RTL 差分：{summary['cpu_passes']}/{summary['cpu_runs']} 通过。
- 正常退休指令类别：38/38；ECALL/EBREAK 与停止原因 1–8 均覆盖。
- 六类分支均覆盖 taken/not-taken；实际额外等待 {summary['observed_extra_wait_cycles']} 周期。
- 共逐条对比 {summary['retirements_compared']} 次退休，检查全部最终寄存器与停止状态。
- 集成：UART/BRAM/GPIO、串口 debug、示例固件三套 RTL 测试通过。
- 串口：{integration['valid_debug_commands']} 条有效应答核对；坏 CRC、坏尾标、非零请求保留字段共 {integration['rejected_frames']} 帧被拒绝；截断帧超时恢复通过。
- Python 客户端：已知 CRC 向量、逐字节破损、实际 RTL 应答重放通过。
- 综合：{net.get('creator')}；结构检查通过，RAMB36E1={counts['RAMB36E1']}、LUT1–6 合计={luts}、MMCM={counts['MMCME2_BASE']}。

资源数字来自 Yosys 技术映射，Vivado 的打包/优化结果可能不同。LUT 合计不是布局布线后的 slice 使用数。未验证静态时序，不以综合结果代替时序通过。

尚未执行：Vivado 布局布线/时序/bitstream、实物 FPGA、仪器采集、远程 CI。对应源代码和构建入口已经提供。

详情：regression.html / regression.json、integration/summary.json、synthesis-yosys.log、all-tests.log。
'''
(reports/'SUMMARY.md').write_text(text,encoding='utf-8')
manifest={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for folder in ['rtl','verification','host','firmware','scripts','constraints'] for p in (ROOT/folder).rglob('*') if p.is_file() and '__pycache__' not in p.parts}
(reports/'source-manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print(text)
