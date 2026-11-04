"""Independent instruction-level RV32I oracle and encoding utilities."""
MASK = 0xffffffff

def signed(x, width=32):
    x &= (1 << width) - 1
    return x - (1 << width) if x & (1 << (width - 1)) else x

def i(op, rd, f3, rs, imm):
    return ((imm & 4095) << 20) | (rs << 15) | (f3 << 12) | (rd << 7) | op

def r(rd, f3, a, b, f7=0):
    return (f7 << 25) | (b << 20) | (a << 15) | (f3 << 12) | (rd << 7) | 0x33

def s(f3, a, b, imm):
    imm &= 4095
    return ((imm >> 5) << 25) | (b << 20) | (a << 15) | (f3 << 12) | ((imm & 31) << 7) | 0x23

def branch(f3, a, b, offset):
    assert offset % 2 == 0 and -4096 <= offset <= 4094
    x = offset & 8191
    return ((x >> 12) << 31) | (((x >> 5) & 63) << 25) | (b << 20) | (a << 15) | (f3 << 12) | (((x >> 1) & 15) << 8) | (((x >> 11) & 1) << 7) | 0x63

def jal(rd, offset):
    assert offset % 2 == 0 and -(1 << 20) <= offset < (1 << 20)
    x = offset & 0x1fffff
    return ((x >> 20) << 31) | (((x >> 1) & 1023) << 21) | (((x >> 11) & 1) << 20) | (((x >> 12) & 255) << 12) | (rd << 7) | 0x6f

class Model:
    def __init__(self, words):
        self.regs = [0] * 32
        self.pc = 0
        self.mem = bytearray(32768)
        for j in range(4096): self.mem[j*4:j*4+4] = (0x00100073).to_bytes(4, 'little')
        for j, word in enumerate(words): self.mem[j*4:j*4+4] = word.to_bytes(4, 'little')
        self.trace = []
        self.coverage = {}
        self.reason = 0

    def index(self, address, size):
        if 0 <= address and address + size <= 16384: return address
        if 0x10000000 <= address and address + size <= 0x10004000: return address - 0x10000000 + 16384
        raise ValueError('access')

    def run(self, limit=10000):
        for _ in range(limit):
            if not self.step(): return self
        raise RuntimeError('oracle instruction timeout')

    def step(self):
        try: ins = int.from_bytes(self.mem[self.index(self.pc,4):self.index(self.pc,4)+4], 'little')
        except ValueError: self.reason=7; return False
        op=ins&127; rd=(ins>>7)&31; f=(ins>>12)&7
        a=self.regs[(ins>>15)&31]; b=self.regs[(ins>>20)&31]; top=ins>>25
        imm=signed(ins>>20,12); nxt=(self.pc+4)&MASK; value=0; write=False
        memory=False; store=False; address=0; data=0; name=''; trap=0
        if op in (0x37,0x17):
            name='LUI' if op==0x37 else 'AUIPC';write=True
            value=(ins&0xfffff000)+(self.pc if op==0x17 else 0)
        elif op==0x6f:
            x=((ins>>31)<<20)|(((ins>>12)&255)<<12)|(((ins>>20)&1)<<11)|(((ins>>21)&1023)<<1)
            name='JAL';value=nxt;write=True;nxt=(self.pc+signed(x,21))&MASK
        elif op==0x67:
            name='JALR';value=nxt;write=True;nxt=(a+imm)&0xfffffffe
            if f!=0: trap=3
        elif op==0x63:
            x=((ins>>31)<<12)|(((ins>>7)&1)<<11)|(((ins>>25)&63)<<5)|(((ins>>8)&15)<<1)
            choices={0:('BEQ',a==b),1:('BNE',a!=b),4:('BLT',signed(a)<signed(b)),5:('BGE',signed(a)>=signed(b)),6:('BLTU',a<b),7:('BGEU',a>=b)}
            if f not in choices: trap=3
            else:
                name,taken=choices[f];self.coverage[name+('_taken' if taken else '_not_taken')]=self.coverage.get(name+('_taken' if taken else '_not_taken'),0)+1
                if taken: nxt=(self.pc+signed(x,13))&MASK
        elif op in (0x13,0x33):
            write=True;c=imm&MASK if op==0x13 else b;shift=(ins>>20)&31 if op==0x13 else b&31
            funcs={0:('ADD',a+c),1:('SLL',a<<shift),2:('SLT',int(signed(a)<signed(c))),3:('SLTU',int(a<c)),4:('XOR',a^c),5:('SRL',a>>shift),6:('OR',a|c),7:('AND',a&c)}
            name,value=funcs[f]
            if op==0x33:
                if top==0x20 and f==0: name,value='SUB',a-b
                elif top==0x20 and f==5: name,value='SRA',signed(a)>>shift
                elif top!=0: trap=3
            else:
                name={'ADD':'ADDI','SLT':'SLTI','SLTU':'SLTIU','XOR':'XORI','OR':'ORI','AND':'ANDI','SLL':'SLLI','SRL':'SRLI'}[name]
                if f==1 and top!=0: trap=3
                if f==5:
                    if top==0x20: name,value='SRAI',signed(a)>>shift
                    elif top!=0: trap=3
        elif op in (3,0x23):
            memory=True;store=op==0x23;write=not store
            choices={0:('SB',1),1:('SH',2),2:('SW',4)} if store else {0:('LB',1),1:('LH',2),2:('LW',4),4:('LBU',1),5:('LHU',2)}
            if f not in choices: trap=3
            else:
                name,size=choices[f]
                off=signed(((ins>>25)<<5)|((ins>>7)&31),12) if store else imm
                address=(a+off)&MASK
                if address%size: trap=6 if store else 5
                else:
                    try:
                        j=self.index(address,size)
                        if store:
                            payload=(b&((1<<(8*size))-1)).to_bytes(size,'little')
                            self.mem[j:j+size]=payload;data=(b<<((address&3)*8))&MASK
                        else:
                            value=int.from_bytes(self.mem[j:j+size],'little')
                            if f in (0,1): value=signed(value,8*size)
                            data=value&MASK
                    except ValueError: trap=8
        elif op==15:
            name='FENCE'
            if f!=0: trap=3
        elif ins==0x00100073: trap=1
        elif ins==0x00000073: trap=2
        else: trap=3
        if not trap and nxt%4: trap=4
        if trap: self.reason=trap;return False
        value&=MASK
        if write and rd: self.regs[rd]=value
        self.trace.append(dict(pc=self.pc,instr=ins,rd=rd if write else 0,value=value if write and rd else 0,mem=int(memory),store=int(store),addr=address,data=data))
        self.coverage[name]=self.coverage.get(name,0)+1
        self.pc=nxt
        return True
