import random
from isa import i,r,s,branch,jal

EBREAK=0x00100073

def cases(seeds=20):
    out={}
    out['smoke']=[i(0x13,1,0,0,5),i(0x13,2,0,0,7),r(3,0,1,2),EBREAK]
    p=[0x800000b7,i(0x13,2,0,0,-1),i(0x13,3,0,0,31),0x12345237,0x00000297]
    for f in range(8):
        p.extend([r(6+f,f,1,2),i(0x13,16+f,f,1,7 if f in (1,5) else -7)])
    p.extend([r(24,0,1,2,0x20),r(25,5,1,3,0x20),i(0x13,26,5,1,0x41f),i(0x13,0,0,0,19),0x0ff0000f,EBREAK])
    out['alu_edges']=p
    p=[0x100000b7,i(0x13,2,0,0,-128),s(2,1,0,0),s(0,1,2,0),s(0,1,2,1),s(1,1,2,2)]
    for f,off in [(0,0),(4,0),(0,1),(4,1),(1,2),(5,2),(2,0)]: p.append(i(3,3+len(p)%20,f,1,off))
    p.extend([i(0x13,2,0,0,127),s(0,1,2,3),i(3,28,2,1,0),s(2,1,28,4),i(3,29,2,1,4),EBREAK]);out['memory_lanes']=p
    for f in [0,1,4,5,6,7]:
        for a,b in [(0,0),(-1,1),(1,-1)]:
            out[f'branch_{f}_{a}_{b}']=[i(0x13,1,0,0,a),i(0x13,2,0,0,b),branch(f,1,2,8),i(0x13,3,0,0,9),EBREAK]
    out['backward_loop']=[i(0x13,1,0,0,4),i(0x13,1,0,1,-1),branch(1,1,0,-4),EBREAK]
    out['jumps']=[jal(1,8),i(0x13,2,0,0,99),i(0x13,3,0,0,21),i(0x67,4,0,3,0),i(0x13,5,0,0,99),0x00000317,EBREAK]
    faults={
        'illegal':[0xffffffff], 'ecall':[0x73], 'bad_shift':[i(0x13,1,1,0,0x20)],
        'bad_register_op':[r(1,0,0,0,1)], 'bad_jalr':[i(0x67,1,1,0,0)],
        'instruction_misaligned':[jal(1,2)],'branch_misaligned':[branch(0,0,0,2)],
        'untaken_misaligned':[branch(1,0,0,2),EBREAK],
        'load_misaligned':[0x100000b7,i(3,2,2,1,1)],
        'store_misaligned':[0x100000b7,s(1,1,0,1)],
        'load_access':[0x300000b7,i(3,0,2,1,0)],
        'store_access':[0x300000b7,s(2,1,0,0)],
        'fetch_access':[0x300000b7,i(0x67,0,0,1,0)],
        'invalid_load':[i(3,1,3,0,0)], 'invalid_store':[s(3,0,0,0)],
        'bad_fence':[0x100f], 'bad_system':[0x00200073],
        'jalr_misaligned':[i(0x13,1,0,0,3),i(0x67,2,0,1,0)],
    }
    out.update(faults)
    for seed in range(seeds):
        rng=random.Random(seed);p=[0x10000fb7]
        for reg in range(1,16): p.append(i(0x13,reg,0,0,rng.randrange(-2048,2048)))
        for _ in range(150):
            rd=rng.randrange(0,31);a=rng.randrange(0,31);b=rng.randrange(0,31);f=rng.randrange(8)
            kind=rng.randrange(4)
            if kind==0: p.append(r(rd,f,a,b,0x20 if f in (0,5) and rng.randrange(2) else 0))
            elif kind==1:
                imm=rng.randrange(32) if f in (1,5) else rng.randrange(-2048,2048)
                if f==5 and rng.randrange(2): imm|=0x400
                p.append(i(0x13,rd,f,a,imm))
            elif kind==2: p.append(s(rng.randrange(3),31,b,4*rng.randrange(64)))
            else: p.append(i(3,rd,rng.choice([0,1,2,4,5]),31,4*rng.randrange(64)))
        out[f'random_{seed:03d}']=p+[EBREAK]
    return out
