"""Resume only flushed prefix, extract disjoint exact-oracle ranges in processes."""
import argparse,subprocess,os,time
from pathlib import Path
from adapt_quant_heads import ROOT,DEP,read,save,sha,verify_plan,targets_letterbox

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--experiment',type=Path,required=True)
    a=p.parse_args();out=a.experiment.resolve();verify_plan(out)
    assert not (out/'cache_result.json').exists()
    import numpy as np
    from PIL import Image
    rows=read(out/'unique_train.json');n=len(rows)
    begin=read(out/'cache_progress.json')['completed']
    # All rows below begin were flushed before the serial process stopped.
    # Preserve a prefix sample and compare it bit-for-bit at completion.
    prefix={}
    for name in ['float_0','float_1','float_2','q15_0','q15_1','q15_2']:
        prefix[name]=np.array(np.load(out/f'features/{name}.npy',mmap_mode='r')[:16])
    ranges=[]
    for i in range(4):
        lo=begin+(n-begin)*i//4;hi=begin+(n-begin)*(i+1)//4
        ranges.append([lo,hi])
    save(out/'cache_resume_001.json',dict(flushed_prefix=begin,range_partition=ranges,workers=4,threads_each=2,
        arithmetic='Unchanged float64 Q15 oracle; independent disjoint output rows.',
        plan_sha256=sha(out/'plan.json'),gradient_steps=0))
    start=time.time();workers=[];env=os.environ.copy();env['PYTHONUTF8']='1'
    script=ROOT/'project/trash_sorting/tools/overnight/adapt_quant_heads.py'
    for lo,hi in ranges:
        log=(out/f'worker_{lo}_{hi}.log').open('x',encoding='utf8')
        cmd=[str(ROOT/'build/trash_train_env/Scripts/python.exe'),str(script),'cache','--out',str(out),
            '--resume-cache','--start-index',str(lo),'--stop-index',str(hi)]
        workers.append((subprocess.Popen(cmd,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT),log,lo,hi))
    for process,log,lo,hi in workers:
        rc=process.wait();log.close()
        if rc:raise RuntimeError(f'Feature worker {lo}:{hi} failed: {rc}')
        assert read(out/f'worker_{lo}_{hi}_result.json')['status']=='PASS'
    for name,expected in prefix.items():np.testing.assert_array_equal(expected,np.load(out/f'features/{name}.npy',mmap_mode='r')[:16])
    # Reconstruct full target list from verified unchanged train labels, using
    # physical pixel dimensions (the header audit excluded all EXIF rotations).
    gt=[]
    for row in rows:
        assert row['split']=='train'
        image=Path(row['prepared_image'])
        with Image.open(image) as im:
            assert im.getexif().get(274,1)==1
            w,h=im.size
        label=Path(image.as_posix().replace('/images/','/labels/')).with_suffix('.txt')
        actual=np.asarray([[float(v) for v in s.split()] for s in label.read_text().splitlines() if s.strip()],dtype=np.float32).reshape(-1,5)
        np.testing.assert_allclose(actual,np.asarray(row['boxes'],dtype=np.float32).reshape(-1,5),rtol=0,atol=1e-5)
        gt.append(targets_letterbox(row['boxes'],w,h))
    for lo,hi in ranges:assert gt[lo:hi]==read(out/f'worker_{lo}_{hi}_result.json')['targets']
    save(out/'features/targets.json',gt)
    files={p.name:sha(p) for p in (out/'features').iterdir() if p.is_file()}
    bundle=read(DEP/'bundle.json')
    save(out/'cache_result.json',dict(status='PASS',images=n,elapsed_s=time.time()-start,
        plan_sha256=sha(out/'plan.json'),float_head_max_error=max(read(out/f'worker_{lo}_{hi}_result.json')['float_head_max_error'] for lo,hi in ranges),
        files=files,feature_ops=[65,73,81],scales=[bundle['ops'][82+h]['input_scales'][0] for h in range(3)],
        target_counts={str(c):sum(int(b[0])==c for items in gt for b in items) for c in range(5)},
        resumed_flushed_prefix=begin,prefix_sample_unchanged=True,range_partition=ranges))
    print('CACHE_COMPLETE '+str(n),flush=True)

if __name__=='__main__':main()
