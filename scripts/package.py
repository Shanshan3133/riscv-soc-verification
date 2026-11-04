"""Zip source and evidence, excluding tool binaries and compiled simulation."""
from pathlib import Path
from zipfile import ZipFile,ZIP_DEFLATED
ROOT=Path(__file__).resolve().parents[1]
archive=ROOT.parent/'riscv-soc-project.zip'
with ZipFile(archive,'w',ZIP_DEFLATED,compresslevel=9) as bundle:
    for path in sorted(ROOT.rglob('*')):
        if not path.is_file():continue
        relative=path.relative_to(ROOT)
        if any(x in relative.parts for x in ['.tools','__pycache__','build']):continue
        if path.suffix in ['.vvp','.pyc']:continue
        bundle.write(path,str(Path('riscv-soc')/relative))
print(archive,archive.stat().st_size,'bytes')
