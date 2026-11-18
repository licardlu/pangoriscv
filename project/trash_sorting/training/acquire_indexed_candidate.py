"""Reuse the verified range/CRC acquisition for a newly indexed candidate.

Acquisition is not admission. Upstream test paths stay unextracted.
"""
import argparse
import json
from pathlib import Path
import sys
import acquire_20k_sources


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root',type=Path,required=True)
    parser.add_argument('--source',required=True)
    args=parser.parse_args()
    assert args.source and all(c.isalnum() or c=='_' for c in args.source)
    index=json.loads((args.root/'indexes'/args.source/'index.json').read_text(encoding='utf8'))
    assert index['url']=='https://www.kaggle.com/api/v1/datasets/download/'+index['source']+'?datasetVersionNumber='+str(index['version'])
    assert 0<index['archive_bytes']<1024**3
    acquire_20k_sources.SOURCES[args.source]=(index['source'],index['version'])
    sys.argv=[sys.argv[0],'--root',str(args.root),'--source',args.source]
    acquire_20k_sources.main()


if __name__=='__main__':
    main()
