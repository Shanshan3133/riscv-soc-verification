"""Wire codec: CRC16-CCITT-FALSE, fixed 16 byte, little endian."""
import struct

MAGIC=0xa5
HALT,RESET,READ_REG,READ_MEM,WRITE_MEM,STEP,RUN,STATUS=range(1,9)

def crc16(data):
    crc=0xffff
    for byte in data:
        crc^=byte<<8
        for _ in range(8): crc=((crc<<1)^0x1021 if crc&0x8000 else crc<<1)&0xffff
    return crc

def encode(command,sequence,address=0,data=0,status=0):
    head=struct.pack('<BBBBII',MAGIC,command,sequence,status,address,data)
    return head+struct.pack('<H',crc16(head))+b'\x5a\xc3'

def decode(frame):
    if len(frame)!=16 or frame[0]!=MAGIC or frame[-2:]!=b'\x5a\xc3': raise ValueError('frame format')
    if crc16(frame[:12])!=int.from_bytes(frame[12:14],'little'): raise ValueError('frame CRC')
    _,cmd,seq,status,address,data=struct.unpack('<BBBBII',frame[:12])
    return dict(command=cmd,sequence=seq,status=status,pc=address,data=data)
