"""Single entry point for non-hardware validation."""
import subprocess,sys,os
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
os.chdir(ROOT)
commands=[['verification/offline_smoke.py'],['verification/run.py'],['verification/run_integration.py'],['verification/test_host.py']]
for args in commands:subprocess.run([sys.executable]+args,check=True)
print('ALL non-hardware regression suites passed. See reports/.')
