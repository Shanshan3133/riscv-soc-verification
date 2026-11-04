"""Compile real RTL, compare every retirement and final register with oracle."""
import argparse,csv,hashlib,json,os,shutil,subprocess,time,html
from pathlib import Path
from isa import Model
from cases import cases

ROOT=Path(__file__).resolve().parents[1]

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--iverilog');ap.add_argument('--seeds',type=int,default=20)
    ap.add_argument('--out',type=Path,default=ROOT/'reports');args=ap.parse_args()
    compiler=args.iverilog or os.environ.get('IVERILOG') or shutil.which('iverilog')
    if not compiler:
        for candidate in [ROOT/'.tools/mingw64/bin/iverilog.exe',ROOT.parents[1]/'work/tools/mingw64/bin/iverilog.exe']:
            if candidate.exists(): compiler=str(candidate);break
    if not compiler: ap.error('Icarus Verilog required: set IVERILOG or --iverilog')
    compiler=Path(compiler).resolve();vvp=compiler.parent/('vvp.exe' if os.name=='nt' else 'vvp')
    env=os.environ.copy();env['PATH']=str(compiler.parent)+os.pathsep+env.get('PATH','')
    args.out.mkdir(parents=True,exist_ok=True);build=args.out/'build';build.mkdir(exist_ok=True)
    flags=[str(compiler)]
    lib=compiler.parent.parent/'lib/ivl'
    if lib.exists(): flags+=['-B',str(lib)]
    sources=[ROOT/'rtl/core/rv32_core.sv',ROOT/'verification/tb_core.sv']
    binary=build/'core.vvp'
    compilation=subprocess.run(flags+['-g2012','-s','tb_core','-o',str(binary)]+list(map(str,sources)),capture_output=True,text=True,env=env,timeout=60)
    (build/'compile.log').write_text(compilation.stdout+compilation.stderr,encoding='utf-8')
    if compilation.returncode: raise RuntimeError(compilation.stderr)
    results=[];coverage={};trap_coverage={};start=time.time()
    for name,words in cases(args.seeds).items():
        oracle=Model(words).run()
        trap_coverage[str(oracle.reason)]=trap_coverage.get(str(oracle.reason),0)+1
        for k,v in oracle.coverage.items(): coverage[k]=coverage.get(k,0)+v
        folder=args.out/'cases'/name;folder.mkdir(parents=True,exist_ok=True)
        image=folder/'program.hex';image.write_text(''.join(f'{w:08x}\n' for w in words),encoding='ascii')
        for delay in (0,3):
            prefix=folder/f'wait{delay}';trace=prefix.with_suffix('.csv');regs=prefix.with_suffix('.regs');reason=prefix.with_suffix('.halt')
            cmd=[str(vvp),'-M',str(lib),str(binary),f'+IMAGE={image}',f'+TRACE={trace}',f'+REGS={regs}',f'+REASON={reason}',f'+DELAY={delay}',f'+SEED={17+delay}']
            if name=='smoke' and delay==0:cmd.append(f'+VCD={args.out / "smoke.vcd"}')
            proc=subprocess.run(cmd,capture_output=True,text=True,env=env,timeout=30)
            prefix.with_suffix('.log').write_text(proc.stdout+proc.stderr,encoding='utf-8')
            error=None;actual=[];cycles=0;wait_observed=0
            try:
                if proc.returncode: raise AssertionError(proc.stdout+proc.stderr)
                with trace.open() as fp:
                    for row in csv.DictReader(fp): actual.append({k:int(v,10 if k in ('rd','mem','store') else 16) for k,v in row.items()})
                if len(actual)!=len(oracle.trace): raise AssertionError(f'retired count {len(actual)} != {len(oracle.trace)}')
                for idx,(got,want) in enumerate(zip(actual,oracle.trace)):
                    keys=['pc','instr','rd','value','mem','store']+(['addr','data'] if want['mem'] else [])
                    for key in keys:
                        if got[key]!=want[key]: raise AssertionError(f'PC {want["pc"]:08x}, retirement {idx}, {key}: {got[key]:08x} != {want[key]:08x}')
                actual_regs=[int(x,16) for x in regs.read_text().split()]
                if actual_regs!=oracle.regs: raise AssertionError('final register mismatch')
                reason_value,pc_value,cycles,wait_observed=reason.read_text().split();cycles=int(cycles);wait_observed=int(wait_observed)
                if int(reason_value)!=oracle.reason or int(pc_value,16)!=oracle.pc: raise AssertionError(f'halt mismatch: {reason_value} {pc_value}, expected {oracle.reason} {oracle.pc:08x}')
            except Exception as exc: error=str(exc)
            results.append(dict(case=name,wait_max=delay,wait_observed=wait_observed,status='FAIL' if error else 'PASS',error=error,cycles=cycles,retired=len(actual),program_sha256=hashlib.sha256(image.read_bytes()).hexdigest()))
            print(f'{results[-1]["status"]} {name} wait={delay}'+(f' {error}' if error else ''),flush=True)
    required=set('LUI AUIPC JAL JALR BEQ BNE BLT BGE BLTU BGEU LB LH LW LBU LHU SB SH SW ADDI SLTI SLTIU XORI ORI ANDI SLLI SRLI SRAI ADD SUB SLL SLT SLTU XOR SRL SRA OR AND FENCE'.split())
    missing=sorted(required-set(coverage))
    branch_missing=[f'{name}_{side}' for name in ['BEQ','BNE','BLT','BGE','BLTU','BGEU'] for side in ['taken','not_taken'] if f'{name}_{side}' not in coverage]
    missing_traps=sorted(set(map(str,range(1,9)))-set(trap_coverage))
    coverage_pass=not(missing or branch_missing or missing_traps) and any(x['wait_observed']>0 for x in results)
    version=subprocess.run([str(vvp),'-V'],capture_output=True,text=True,env=env,timeout=10)
    report=dict(kind='RTL simulation; no physical hardware',elapsed_seconds=round(time.time()-start,2),compiler=str(compiler),tool_version=(version.stdout+version.stderr).splitlines()[0],source_sha256={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sources},coverage=coverage,trap_coverage=trap_coverage,coverage_gate=dict(passed=coverage_pass,required_instructions=len(required),missing=missing,missing_branches=branch_missing,missing_traps=missing_traps),results=results)
    (args.out/'regression.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    rows=''.join(f'<tr><td>{html.escape(x["case"])}</td><td>{x["wait_max"]}</td><td>{x["status"]}</td><td>{x["cycles"]}</td><td>{html.escape(x["error"] or "")}</td></tr>' for x in results)
    cov=''.join(f'<tr><td>{k}</td><td>{v}</td></tr>' for k,v in sorted(coverage.items()))
    (args.out/'regression.html').write_text('<!doctype html><meta charset="utf-8"><title>RV32I RTL regression</title><style>body{font:16px system-ui;margin:32px}td,th{padding:6px;border:1px solid #ccc}table{border-collapse:collapse}</style><h1>RV32I RTL regression</h1><p>Independent Python oracle; instruction functional coverage, not RTL code coverage. No hardware tested.</p><table><tr><th>Case</th><th>Wait</th><th>Status</th><th>Cycles</th><th>Failure</th></tr>'+rows+'</table><h2>Instruction execution counts</h2><table>'+cov+'</table>',encoding='utf-8')
    failures=sum(x['status']=='FAIL' for x in results)
    print(f'{len(results)-failures}/{len(results)} passed; report: {args.out / "regression.html"}')
    print(f'Functional coverage gate: {"PASS" if coverage_pass else "FAIL"}; {len(required)} instruction kinds plus ECALL/EBREAK, both branch outcomes, reasons 1..8, observed waits')
    raise SystemExit(bool(failures) or not coverage_pass)

if __name__=='__main__': main()
