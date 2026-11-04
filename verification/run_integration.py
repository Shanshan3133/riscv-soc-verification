"""Real UART waveform tests: fabric/peripheral and host-codec/debug/SoC."""
import argparse,os,shutil,subprocess,sys,json,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'host'))
from protocol import encode,decode,crc16

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--iverilog');args=ap.parse_args()
    compiler=args.iverilog or os.getenv('IVERILOG') or shutil.which('iverilog')
    if not compiler:
        compiler=ROOT/'.tools/mingw64/bin/iverilog.exe'
        if not compiler.exists():compiler=ROOT.parents[1]/'work/tools/mingw64/bin/iverilog.exe'
    compiler=Path(compiler).resolve();lib=compiler.parent.parent/'lib/ivl'
    env=os.environ.copy();env['PATH']=str(compiler.parent)+os.pathsep+env.get('PATH','')
    folder=ROOT/'reports/integration';folder.mkdir(parents=True,exist_ok=True)
    sources=sorted((ROOT/'rtl').rglob('*.sv'))
    assert crc16(b'123456789')==0x29b1
    frames=[];expected=[];seq=0
    def command(cmd,address=0,data=0,status=0,value=None,pc=None):
        nonlocal seq
        seq+=1;frames.append(encode(cmd,seq,address,data))
        expected.append(dict(command=cmd|128,sequence=seq,status=status,value=value,pc=pc))
    command(8,value=1,pc=0)
    damaged=bytearray(encode(5,200,0,0xffffffff));damaged[12]^=1;frames.append(damaged)
    damaged_tail=bytearray(encode(5,201,0,0xffffffff));damaged_tail[-1]^=1;frames.append(damaged_tail)
    frames.append(encode(5,202,0,0xffffffff,status=1))
    command(4,0,value=0x00100073,pc=0) # invalid frame must not write memory
    command(2,value=0,pc=0)
    for address,word in enumerate([0x00500093,0x00700113,0x002081b3,0x00100073]):
        command(5,address*4,word,pc=0);command(4,address*4,value=word,pc=0)
    command(3,data=0,value=0,pc=0)
    command(6,value=9,pc=4);command(3,data=1,value=5,pc=4)
    command(6,value=9,pc=8);command(3,data=2,value=7,pc=8)
    command(7,data=1000,value=1,pc=12);command(3,data=3,value=12,pc=12)
    command(3,data=32,status=1,pc=12);command(4,address=0x30000000,status=3,pc=12)
    command(4,address=1,status=1,pc=12)
    command(5,address=0x20000100,data=15,pc=12)
    command(4,address=0x20000100,value=15,pc=12)
    command(2,value=0,pc=0);command(3,data=1,value=0,pc=0)
    command(5,address=0,data=0x0000006f,pc=0)
    command(7,data=40,status=4,value=9,pc=0)
    command(1,value=9,pc=0);command(8,value=19,pc=0)
    command(7,data=0,status=1,pc=0)
    command(5,address=0,data=0xffffffff,pc=0);command(2,value=0,pc=0)
    command(7,data=1000,value=3,pc=0);command(6,status=2,pc=0)
    command(99,status=1,pc=0)
    frames_path=folder/'requests.hex'
    frames_path.write_text(''.join(bytes(frame)[::-1].hex()+'\n' for frame in frames),encoding='ascii')
    (folder/'expected.json').write_text(json.dumps(expected,indent=2),encoding='utf-8')
    results=[]
    subprocess.run([sys.executable,str(ROOT/'firmware/build_demo.py')],check=True)
    for top in ['tb_peripherals','tb_debug','tb_demo']:
        binary=folder/f'{top}.vvp';cmd=[str(compiler)]
        if lib.exists():cmd+=['-B',str(lib)]
        cmd+=['-g2012','-s',top,'-o',str(binary)]+list(map(str,sources))+[str(ROOT/f'verification/{top}.sv')]
        proc=subprocess.run(cmd,env=env,capture_output=True,text=True,timeout=60)
        (folder/f'{top}.compile.log').write_text(proc.stdout+proc.stderr,encoding='utf-8')
        if proc.returncode: raise RuntimeError(proc.stderr)
        cmd=[str(compiler.parent/('vvp.exe' if os.name=='nt' else 'vvp')),'-M',str(lib),str(binary)]
        if top=='tb_debug':cmd += [f'+FRAMES={frames_path}',f'+RESPONSES={folder / "responses.hex"}',f'+COUNT={len(frames)}']
        proc=subprocess.run(cmd,env=env,capture_output=True,text=True,timeout=60)
        (folder/f'{top}.log').write_text(proc.stdout+proc.stderr,encoding='utf-8')
        if proc.returncode:raise RuntimeError(proc.stdout+proc.stderr)
        print(proc.stdout.strip(),flush=True)
        results.append(dict(test=top,status='PASS'))
    actual=[decode(bytes.fromhex(line)[::-1]) for line in (folder/'responses.hex').read_text().splitlines()]
    assert len(actual)==len(expected),(len(actual),len(expected))
    for index,(got,want) in enumerate(zip(actual,expected)):
        for key in ['command','sequence','status','pc','value']:
            if key in want and want[key] is not None:
                actual_key='data' if key=='value' else key
                assert got[actual_key]==want[key],(index,key,got,want)
    report=dict(kind='RTL UART waveform simulation; no hardware',results=results,valid_debug_commands=len(expected),rejected_frames=3,truncated_frame_timeout=True,
                source_sha256={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sources})
    (folder/'summary.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(f'PASS: {len(expected)} debug responses matched host codec, PC, register and memory expectations')

if __name__=='__main__':main()
