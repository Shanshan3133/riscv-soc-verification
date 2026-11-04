"""Host protocol and client tests, replaying real RTL serial responses."""
import sys,unittest,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'host'))
from protocol import crc16,encode,decode
from client import Client

class Replay:
    def __init__(self,request,response):self.request=request;self.response=response;self.buffer=bytearray();self.cursor=0
    def write(self,value):
        if value!=self.request:raise AssertionError('unexpected host request')
        self.buffer=bytearray(b'noise'+self.response)
    def read(self,length):
        count=min(length,3,len(self.buffer));data=bytes(self.buffer[:count]);del self.buffer[:count];return data

class HostTests(unittest.TestCase):
    def test_crc_known_vector(self):self.assertEqual(crc16(b'123456789'),0x29b1)
    def test_corruption(self):
        packet=encode(4,17,0x10000000,0x80000000)
        self.assertEqual(decode(packet)['data'],0x80000000)
        for byte in range(16):
            corrupt=bytearray(packet);corrupt[byte]^=1
            with self.assertRaises(ValueError):decode(corrupt)
    def test_rtl_response_replay(self):
        folder=ROOT/'reports/integration'
        expected=json.loads((folder/'expected.json').read_text())
        responses=[bytes.fromhex(line)[::-1] for line in (folder/'responses.hex').read_text().splitlines()]
        requests=[bytes.fromhex(line)[::-1] for line in (folder/'requests.hex').read_text().splitlines()]
        by_seq={decode(frame)['sequence']:frame for frame in requests if decode_safe(frame)}
        for want,response in zip(expected,responses):
            request=by_seq[want['sequence']];fields=decode(request)
            client=Client(Replay(request,response));client.sequence=want['sequence']-1
            if want['status']:
                with self.assertRaises(RuntimeError):client.command(fields['command'],fields['pc'],fields['data'])
            else:self.assertEqual(client.command(fields['command'],fields['pc'],fields['data']),decode(response))

def decode_safe(frame):
    try:decode(frame);return True
    except ValueError:return False

if __name__=='__main__':unittest.main()
