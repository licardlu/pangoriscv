"""Fill optional primary-bin metadata in a separate train-only diagnostic view.

No training input, label or manifest is changed; no images are opened here.
"""
from pathlib import Path
from collections import Counter
from adapt_quant_heads import read,save,sha


def main():
    source=Path('build/noon_continuation_20261118_001/research/organic_001/reviewed_dataset_001/manifest.json')
    out=Path('build/train_quant_gap_20261118_001/metadata_001');out.mkdir(parents=True,exist_ok=False)
    unique={r['image_sha256']:dict(r) for r in read(source) if r['split']=='train'}
    repairs=[]
    for key,row in unique.items():
        if 'primary_bin' not in row:
            row['primary_bin']=int(max(row['boxes'],key=lambda b:b[3]*b[4])[0]) if row['boxes'] else 4
            repairs.append(key)
    save(out/'manifest.json',list(unique.values()))
    save(out/'provenance.json',dict(source_manifest_sha256=sha(source),
        train_file_identities=len(unique),missing_primary_metadata_filled=len(repairs),
        filled_ids=repairs,method='Largest-box class; no boxes uses hand/negative bucket4 only for stratified training diagnostics.',
        primary_counts=dict(Counter(r['primary_bin'] for r in unique.values())),
        source_manifest_changed=False,images_opened=False,training_or_labels_changed=False))
    print(out,flush=True)


if __name__=='__main__':main()
