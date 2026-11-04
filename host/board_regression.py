"""Prepared hardware regression; requires programmed board, never auto-runs."""
import argparse,sys,time,json,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'verification'))
from cases import cases
from isa import Model
from client import Client

def run(client,tests,metadata,out):
    out.mkdir(parents=True,exist_ok=True);results=[]
    for name,words in tests.items():
        oracle=Model(words).run();error=None;start=time.monotonic()
        try:
            client.reset()
            for address,word in enumerate(words):client.write_mem(address*4,word)
            # Zero all data words touched by this oracle execution, avoiding stale state.
            touched={t['addr']&~3 for t in oracle.trace if t['mem'] and 0x10000000<=t['addr']<0x10004000}
            for address in sorted(touched):client.write_mem(address,0)
            response=client.run(100000)
            if response['data']!=oracle.reason or response['pc']!=oracle.pc:raise AssertionError('stop state mismatch')
            regs=[client.read_reg(index) for index in range(32)]
            if regs!=oracle.regs:raise AssertionError('register mismatch')
            for address in sorted(touched):
                j=oracle.index(address,4);wanted=int.from_bytes(oracle.mem[j:j+4],'little')
                if client.read_mem(address)!=wanted:raise AssertionError(f'memory mismatch {address:08x}')
        except Exception as exc:error=str(exc)
        results.append(dict(case=name,status='FAIL' if error else 'PASS',error=error,seconds=round(time.monotonic()-start,3),image_sha256=hashlib.sha256(b''.join(w.to_bytes(4,'little') for w in words)).hexdigest()))
        (out/'board-regression.json').write_text(json.dumps(dict(metadata=metadata,results=results),indent=2),encoding='utf-8')
        print(results[-1],flush=True)
    return results

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--port',required=True);ap.add_argument('--board',required=True)
    ap.add_argument('--bitstream',required=True,type=Path);ap.add_argument('--seeds',type=int,default=5)
    ap.add_argument('--out',type=Path,default=ROOT/'reports/hardware');args=ap.parse_args()
    import serial
    metadata=dict(kind='physical FPGA test',board=args.board,port=args.port,bitstream_sha256=hashlib.sha256(args.bitstream.read_bytes()).hexdigest(),seeds=args.seeds)
    with serial.Serial(args.port,115200,timeout=.1,write_timeout=2) as port:
        port.reset_input_buffer();results=run(Client(port),cases(args.seeds),metadata,args.out)
    raise SystemExit(any(row['status']=='FAIL' for row in results))

if __name__=='__main__':main()
