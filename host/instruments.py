"""Adapters for later hardware use. No instrument is contacted at import."""
from pathlib import Path

class ScpiInstrument:
    def __init__(self,resource,timeout_ms=5000):
        import pyvisa
        self.manager=pyvisa.ResourceManager()
        self.device=self.manager.open_resource(resource)
        self.device.timeout=timeout_ms
    def identify(self): return self.device.query('*IDN?').strip()
    def write(self,command): return self.device.write(command)
    def query(self,command): return self.device.query(command)
    def close(self): self.device.close();self.manager.close()
    # Trigger/waveform commands differ by model; no guessed SCPI commands.

class SaleaeCapture:
    def capture(self,folder,channels=(0,1,2,3),sample_rate=10_000_000,duration=0.1,device_id=None):
        from saleae import automation
        folder=Path(folder);folder.mkdir(parents=True,exist_ok=True)
        with automation.Manager.connect(port=10430) as manager:
            kwargs=dict(device_configuration=automation.LogicDeviceConfiguration(
                enabled_digital_channels=list(channels),digital_sample_rate=sample_rate),
                capture_configuration=automation.CaptureConfiguration(
                    capture_mode=automation.TimedCaptureMode(duration_seconds=duration)))
            if device_id is not None: kwargs['device_id']=device_id
            with manager.start_capture(**kwargs) as capture:
                capture.wait();capture.save_capture(str(folder/'capture.sal'))
                capture.export_raw_data_csv(directory=str(folder),digital_channels=list(channels))
        return folder/'capture.sal'
