"""Move only untracked root-level PDS scratch into the user's trash folder."""
import json
from pathlib import Path
import subprocess
from datetime import datetime, timezone


ROOT=Path(__file__).resolve().parents[4]


def main():
    trash=(ROOT/'垃圾文件'/'pds_root_output_20261119_001').resolve()
    assert trash.is_relative_to(ROOT) and not trash.exists()
    names=['compile','constraint_check','device_map','place_route','synthesize','logbackup',
           'flow.log','impl.tcl','multiseed_summary.csv']
    pending=[]
    for name in names:
        source=(ROOT/name).resolve()
        destination=(trash/name).resolve()
        assert source.parent==ROOT and destination.parent==trash and destination.is_relative_to(ROOT)
        assert not (ROOT/name).is_symlink()
        if source.exists():
            tracked=subprocess.check_output(['git','ls-files','-z','--',name],cwd=ROOT)
            assert not tracked, 'Do not move tracked files: '+name
            pending.append((source,destination))
    trash.mkdir(parents=True)
    records=[]
    for source,destination in pending:
        files=[p for p in source.rglob('*') if p.is_file()] if source.is_dir() else [source]
        size=sum(p.stat().st_size for p in files)
        source.rename(destination)
        records.append(dict(original=str(source),destination=str(destination),files=len(files),bytes=size))
    (trash/'移动清单.json').write_text(json.dumps(dict(reason='User requested generated disposable output outside source upload',
        utc=datetime.now(timezone.utc).isoformat(),files=records),ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print(json.dumps(dict(moved_items=len(records),bytes=sum(r['bytes'] for r in records),trash=str(trash)),ensure_ascii=True),flush=True)


if __name__=='__main__':
    main()
