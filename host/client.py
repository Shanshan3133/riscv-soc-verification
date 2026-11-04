"""Real serial client. Optional pyserial is imported only for real devices."""
import argparse,json,time
from pathlib import Path
from protocol import *

class Client:
    def __init__(self,transport): self.transport=transport;self.sequence=0
    def command(self,cmd,address=0,data=0,timeout=5):
        self.sequence=(self.sequence+1)&255
        self.transport.write(encode(cmd,self.sequence,address,data))
        deadline=time.monotonic()+timeout;buffer=bytearray()
        while time.monotonic()<deadline:
            buffer.extend(self.transport.read(16-len(buffer)))
            if buffer and buffer[0]!=MAGIC: del buffer[0];continue
            if len(buffer)<16: continue
            try: response=decode(buffer)
            except ValueError: del buffer[0];continue
            if response['sequence']!=self.sequence or response['command']!=(cmd|128): buffer.clear();continue
            if response['status']!=0: raise RuntimeError(f'debug error: {response}')
            return response
        raise TimeoutError('debug response timeout')
    def reset(self): return self.command(RESET)
    def halt(self): return self.command(HALT)
    def status(self): return self.command(STATUS)
    def read_reg(self,index): return self.command(READ_REG,data=index)['data']
    def read_mem(self,address): return self.command(READ_MEM,address=address)['data']
    def write_mem(self,address,value): return self.command(WRITE_MEM,address,value)
    def step(self): return self.command(STEP)
    def run(self,cycles=100000): return self.command(RUN,data=cycles)
    def load(self,path):
        self.reset()
        words=[int(line.split('//')[0].strip(),16) for line in Path(path).read_text().splitlines() if line.split('//')[0].strip()]
        if len(words)>4096: raise ValueError('program exceeds 16 KiB')
        for index,word in enumerate(words):
            self.write_mem(index*4,word)
            if self.read_mem(index*4)!=word: raise RuntimeError(f'load verify failed at {index*4:08x}')

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--port',required=True);ap.add_argument('--baud',type=int,default=115200)
    ap.add_argument('--image',type=Path);ap.add_argument('--cycles',type=int,default=100000)
    args=ap.parse_args()
    import serial
    with serial.Serial(args.port,args.baud,timeout=0.1,write_timeout=2) as port:
        port.reset_input_buffer();client=Client(port)
        if args.image: client.load(args.image);client.run(args.cycles)
        result={'status':client.status(),'registers':[client.read_reg(x) for x in range(32)]}
        print(json.dumps(result,indent=2))

if __name__=='__main__':main()
