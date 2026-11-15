"""Join binary split volumes and verify the exact original archive; uses Python standard library only."""
from pathlib import Path
import json,hashlib,sys
root=Path(__file__).resolve().parent
manifest=json.loads((root/'bundle-parts-sha256.json').read_text(encoding='utf8'))
out=root/manifest['archive_name']
if out.exists():raise SystemExit('Output exists; move or rename it before merging: '+str(out))
# Validate all parts before creating the merged output.
for row in manifest['parts']:
 p=root/row['name']
 if not p.is_file() or p.stat().st_size!=row['bytes']:raise SystemExit('Missing or wrong size: '+row['name'])
 h=hashlib.sha256()
 with p.open('rb') as f:
  for b in iter(lambda:f.read(8*1024*1024),b''):h.update(b)
 if h.hexdigest()!=row['sha256']:raise SystemExit('SHA256 mismatch: '+row['name'])
 print('Verified',row['name'],flush=True)
h=hashlib.sha256();size=0
with out.open('xb') as dest:
 for row in manifest['parts']:
  with (root/row['name']).open('rb') as f:
   for b in iter(lambda:f.read(8*1024*1024),b''):dest.write(b);h.update(b);size+=len(b)
assert size==manifest['bytes'] and h.hexdigest()==manifest['sha256'],'Merged file verification failed'
print('PASS',out,'bytes',size,'SHA256',h.hexdigest())
