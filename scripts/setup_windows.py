"""Install pinned portable Icarus under .tools, without system/PATH changes."""
import argparse,hashlib,io,json,subprocess,sys,tarfile,urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--dest',type=Path,default=ROOT/'.tools');args=ap.parse_args()
    args.dest.mkdir(parents=True,exist_ok=True)
    python_lib=args.dest/'python'
    subprocess.run([sys.executable,'-m','pip','install','--target',str(python_lib),'zstandard==0.25.0'],check=True)
    sys.path.insert(0,str(python_lib))
    import zstandard
    for entry in json.loads((ROOT/'scripts/windows-tools.json').read_text()):
        print('Downloading',entry['file'],flush=True)
        payload=urllib.request.urlopen(entry['url'],timeout=60).read()
        if hashlib.sha256(payload).hexdigest()!=entry['sha256']:raise RuntimeError('package checksum mismatch')
        with zstandard.ZstdDecompressor().stream_reader(io.BytesIO(payload)) as reader:
            with tarfile.open(fileobj=reader,mode='r|') as archive:archive.extractall(args.dest,filter='data')
    compiler=(args.dest/'mingw64/bin/iverilog.exe').resolve()
    print(f'Use: python verification/run.py --iverilog "{compiler}"')
    print('MSYS2 package metadata and licenses retained under .tools/.')

if __name__=='__main__':main()
