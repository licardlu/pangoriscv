"""Create a clean, checksummed release; no board access or external writes."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
NAME = 'VexiiRiscv改进版'


def package(parent):
    destination = parent / NAME
    archive = parent / (NAME + '.zip')
    if destination.exists() or archive.exists():
        raise FileExistsError('Release already exists; choose a fresh output directory.')
    simulation = (ROOT/'evidence/simulation-final100.log').read_text(encoding='utf-8')
    if 'TEST_PASS soc_coremark' not in simulation:
        raise ValueError('The release diagnostic simulation must finish before packaging.')
    assessment = json.loads((ROOT/'evidence/final100-assessment.json').read_text(encoding='utf-8'))
    if assessment['iterations'] != 100 or assessment['board_verified']:
        raise ValueError('Unexpected diagnostic result or unsubstantiated board claim.')
    destination.mkdir(parents=True)
    ignore = shutil.ignore_patterns('.git', '__pycache__', '*.pyc', 'target', 'null', '*.wlf')
    for directory in ['rtl', 'platform', 'firmware', 'scripts', 'tb',
                      'tools', 'upstream', 'docs', 'evidence', 'bitstream']:
        shutil.copytree(ROOT/directory, destination/directory, ignore=ignore)
    (destination/'project').mkdir()
    for item in (ROOT/'project').iterdir():
        if item.is_file() and item.suffix in {'.pds', '.bin'}:
            shutil.copy2(item, destination/'project'/item.name)
    for filename in ['README.md', 'THIRD_PARTY_NOTICES.md', '.gitignore']:
        shutil.copy2(ROOT/filename, destination/filename)
    # Test fixtures and the exact release inputs, without simulator work libraries.
    for directory in ['firmware_100', 'firmware_7000', 'gen_final100', 'gen_final7000']:
        source = ROOT/'build'/directory
        target = destination/'build'/directory
        target.mkdir(parents=True)
        for item in source.iterdir():
            if item.is_file() and item.suffix in {'.elf', '.dis', '.map', '.h', '.json', '.log', '.v', '.bin'}:
                shutil.copy2(item, target/item.name)

    # Confirm that the portable project references only files inside the package.
    import re
    project = destination/'project/VexiiRiscv_improved.pds'
    referenced = re.findall(r'\(_file "([^"]+)"', project.read_text())
    for filename in referenced:
        resolved = (project.parent/filename).resolve()
        resolved.relative_to(destination.resolve())
        if not resolved.is_file():
            raise FileNotFoundError(filename)
    runtime = json.loads((destination/'tools/runtime/classpath.json').read_text())
    for filename in runtime:
        if Path(filename).is_absolute() or not (destination/filename).is_file():
            raise ValueError('Nonportable or missing runtime library: '+filename)

    # Check the actual final image and the separate project-working-directory copy.
    sys.path.insert(0, str(destination/'scripts'))
    from verify_image import verify
    elf = destination/'build/firmware_7000/coremark.elf'
    image = verify(elf, destination/'rtl/generated')
    assert image == verify(elf, destination/'project')
    (destination/'evidence/release-image.json').write_text(json.dumps(image, indent=2), encoding='utf-8')

    manifest = []
    for item in sorted(destination.rglob('*')):
        if item.is_file() and '__pycache__' not in item.parts:
            manifest.append(hashlib.sha256(item.read_bytes()).hexdigest()+'  '+item.relative_to(destination).as_posix())
    (destination/'SHA256SUMS.txt').write_text('\n'.join(manifest)+'\n', encoding='utf-8')
    with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as output:
        for item in sorted(destination.rglob('*')):
            if item.is_file() and '__pycache__' not in item.parts:
                output.write(item, NAME+'/'+item.relative_to(destination).as_posix())
    print(json.dumps({'directory':str(destination), 'zip':str(archive),
                      'zip_bytes':archive.stat().st_size, 'files':len(manifest)+1,
                      'zip_sha256':hashlib.sha256(archive.read_bytes()).hexdigest()},
                     ensure_ascii=False, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT/'output/fpga')
    package(parser.parse_args().output.resolve())
