"""Fail publication if disposable directories, caches or oversized assets are staged."""
import argparse
from collections import Counter
import json
from pathlib import Path
import subprocess
from adapt_quant_heads import ROOT


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out',type=Path,required=True)
    args=parser.parse_args()
    names=subprocess.check_output(['git','diff','--cached','--name-only','--diff-filter=ACMR','-z'],cwd=ROOT).decode('utf8').split('\0')
    names=[p for p in names if p]
    assert names
    forbidden=[]
    scratch={'build','__pycache__','.pytest_cache','垃圾文件','compile','constraint_check','device_map','place_route','synthesize','logbackup'}
    cache_extensions={'.npy','.npz','.qdb','.qpg','.qtl','.wlf','.vcd','.pyc','.dmp','.lic','.zip','.7z','.pmj','.pcm'}
    for name in names:
        path=Path(name)
        if set(path.parts)&scratch or path.suffix.lower() in cache_extensions:
            forbidden.append(name)
    # Query index blobs, so this audits exactly what will be committed.
    result=subprocess.run(['git','cat-file','--batch-check=%(objectname) %(objecttype) %(objectsize)'],cwd=ROOT,
        input=''.join(':'+p+'\n' for p in names),capture_output=True,text=True,encoding='utf8',check=True)
    blobs=result.stdout.splitlines();assert len(blobs)==len(names)
    records=[]
    for name,line in zip(names,blobs):
        digest,kind,size=line.split();assert kind=='blob'
        records.append(dict(path=name,git_blob=digest,bytes=int(size)))
    oversized=[r for r in records if r['bytes']>50*1024**2]
    report=dict(status='PASS' if not forbidden and not oversized else 'FAIL',files=len(records),
                staged_file_lengths_MiB=sum(r['bytes'] for r in records)/1024**2,
                unique_blob_lengths_MiB=sum({r['git_blob']:r['bytes'] for r in records}.values())/1024**2,
                forbidden_paths=forbidden,oversized=oversized,
                extension_counts=dict(Counter(Path(r['path']).suffix.lower() for r in records)),
                largest_files=sorted(records,key=lambda r:-r['bytes'])[:12])
    args.out.parent.mkdir(parents=True,exist_ok=True)
    args.out.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print(json.dumps({k:v for k,v in report.items() if k not in ['extension_counts','largest_files']},ensure_ascii=True),flush=True)
    if report['status']!='PASS':raise SystemExit(1)


if __name__=='__main__':
    main()
