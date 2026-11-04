"""Physical-board debug recovery, reset-retention and GPIO checks (no Pmod wires)."""
import argparse, json, time
from pathlib import Path
import serial
from client import Client
from protocol import encode, WRITE_MEM

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--port',required=True)
    ap.add_argument('--out',type=Path,default=Path(__file__).resolve().parents[1]/'reports/hardware/bringup.json')
    args=ap.parse_args(); checks=[]
    with serial.Serial(args.port,115200,timeout=.1,write_timeout=2) as port:
        port.reset_input_buffer(); client=Client(port); client.reset()
        address=0x10003ffc; sentinel=0x13579bdf
        client.write_mem(address,sentinel)
        for name,mode in [('bad_crc','crc'),('bad_tail','tail'),('reserved_status','reserved'),('truncated_frame','truncated')]:
            frame=bytearray(encode(WRITE_MEM,220,address,0xffffffff,status=int(mode=='reserved')))
            if mode=='crc': frame[12]^=1
            if mode=='tail': frame[-1]^=1
            if mode=='truncated': frame=frame[:7]
            port.write(frame); port.flush()
            if mode=='truncated': time.sleep(.15) # 1M cycles / 10MHz = 100ms timeout.
            assert port.read(16)==b'', f'{name}: unexpected reply'
            assert client.read_mem(address)==sentinel, f'{name}: memory changed'
            checks.append(dict(test=name,status='PASS'))
        for index in range(20):
            client.reset()
            assert client.read_mem(address)==sentinel, 'reset corrupted BRAM'
            assert client.read_reg(0)==0 and client.read_reg(1)==0
        checks.append(dict(test='20_soft_resets_preserve_bram_and_clear_registers',status='PASS'))
        for index,word in enumerate([0x00500093,0x00700113,0x002081b3,0x00100073]):
            client.write_mem(index*4,word)
        for pc,register,value in [(4,1,5),(8,2,7),(12,3,12)]:
            assert client.step()['pc']==pc
            assert client.read_reg(register)==value
        response=client.run(1000)
        assert response['pc']==12 and response['data']==1
        checks.append(dict(test='single_step_then_run_to_ebreak',status='PASS'))
        for value in [0,1,2,4,8,15]:
            client.write_mem(0x20000100,value)
            assert client.read_mem(0x20000100)==value
        checks.append(dict(test='gpio_output_register_patterns',status='PASS'))
        switches=client.read_mem(0x20000104)
        client.write_mem(0x20000100,15) # Leave LD0..LD3 lit for visual confirmation.
        result=dict(kind='physical FPGA test',port=args.port,checks=checks,
                    switch_input=switches,final_gpio=15,
                    limits='No external UART loopback, physical-button reset, power cycle, ILA or instrument capture tested.')
        args.out.parent.mkdir(parents=True,exist_ok=True)
        args.out.write_text(json.dumps(result,indent=2),encoding='utf-8')
        print(json.dumps(result,indent=2))

if __name__=='__main__': main()
