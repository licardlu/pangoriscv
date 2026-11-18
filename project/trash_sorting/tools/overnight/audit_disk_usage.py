"""Read-only directory size audit, separating logical size and hardlink identities."""
import argparse
from collections import defaultdict
import json
import os
from pathlib import Path
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--depth', type=int, default=2)
    args = parser.parse_args()
    root = args.root.resolve()
    groups = defaultdict(lambda: dict(files=0, logical_bytes=0, hardlinked_logical_bytes=0,
                                     exclusive_single_link_bytes=0, newest_mtime=0))
    seen = set()
    unique_bytes = 0
    largest = []
    errors = []
    started = time.time()
    stack = [root]
    while stack:
        directory = stack.pop()
        try:
            with os.scandir(directory) as entries:
                for entry in entries:
                    try:
                        if entry.is_symlink():
                            continue
                        if entry.is_dir(follow_symlinks=False):
                            stack.append(Path(entry.path))
                            continue
                        if not entry.is_file(follow_symlinks=False):
                            continue
                        # On Windows DirEntry.stat can report zero inode/nlink;
                        # os.stat performs the handle query needed for hardlinks.
                        st = os.stat(entry.path, follow_symlinks=False)
                        if not st.st_ino or not st.st_nlink:
                            raise RuntimeError('Filesystem identity unavailable: '+entry.path)
                        rel = Path(entry.path).relative_to(root)
                        # Two levels separate build experiments from original datasets.
                        key = '/'.join(rel.parts[:args.depth]) if len(rel.parts)>args.depth else str(rel.parent)
                        group = groups[key]
                        group['files'] += 1
                        group['logical_bytes'] += st.st_size
                        group['hardlinked_logical_bytes'] += st.st_size if st.st_nlink>1 else 0
                        group['exclusive_single_link_bytes'] += st.st_size if st.st_nlink==1 else 0
                        group['newest_mtime'] = max(group['newest_mtime'], st.st_mtime)
                        identity = (st.st_dev, st.st_ino)
                        if identity not in seen:
                            seen.add(identity)
                            unique_bytes += st.st_size
                        if st.st_size >= 100*1024**2:
                            largest.append(dict(path=str(entry.path), bytes=st.st_size, hardlinks=st.st_nlink,
                                                modified_unix=st.st_mtime))
                    except OSError as error:
                        errors.append(dict(path=entry.path, error=str(error)))
        except OSError as error:
            errors.append(dict(path=str(directory), error=str(error)))
    result = dict(status='COMPLETED_READ_ONLY_DISK_AUDIT', root=str(root), elapsed_s=time.time()-started,
                  groups=dict(sorted(groups.items(), key=lambda kv: -kv[1]['logical_bytes'])),
                  logical_bytes=sum(g['logical_bytes'] for g in groups.values()),
                  unique_file_length_bytes=unique_bytes, largest_files=sorted(largest,key=lambda r:-r['bytes'])[:100],
                  errors=errors, limitations=['File lengths are not allocated clusters or volume change since a baseline.',
                      'Unique identities count shared hardlinks once within this root; links outside root may still retain data.',
                      'Exclusive single-link file lengths are an estimate, not a deletion instruction.'])
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print(json.dumps(dict(root=str(root), elapsed_s=result['elapsed_s'], logical_GiB=result['logical_bytes']/1024**3,
        unique_file_length_GiB=unique_bytes/1024**3, errors=len(errors),
        top_groups=[dict(group=k,GiB=round(g['logical_bytes']/1024**3,2),single_link_GiB=round(g['exclusive_single_link_bytes']/1024**3,2))
                    for k,g in list(result['groups'].items())[:22]], largest_files=result['largest_files'][:12]),ensure_ascii=False),flush=True)


if __name__ == '__main__':
    main()
