"""Toolchain-free, reproducible RV32I UART/GPIO demo image."""
from pathlib import Path
import sys,json
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'verification'))
from isa import i,s,branch

def main():
    # x1=UART base; x2=GPIO base; x3=status; x4=character.
    words=[0x200000b7,0x20000137,i(0x13,2,0,2,256),i(0x13,4,0,0,15),s(2,2,4,0)]
    for char in b'RV32I OK\r\n':
        words += [i(3,3,2,1,8),i(0x13,3,7,3,1),branch(0,3,0,-8),i(0x13,4,0,0,char),s(2,1,4,0)]
    words += [i(3,3,2,1,8),i(0x13,3,7,3,1),branch(0,3,0,-8),0x00100073]
    root=Path(__file__).resolve().parent
    (root/'demo.hex').write_text(''.join(f'{x:08x}\n' for x in words),encoding='ascii')
    (root/'demo.expected.json').write_text(json.dumps({'uart_ascii':'RV32I OK\r\n','gpio':15,'halt_reason':1,'halt_pc':4*(len(words)-1)},indent=2)+'\n',encoding='utf-8')
    print(f'Generated demo.hex: {len(words)} instructions')

if __name__=='__main__': main()
