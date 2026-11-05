from pathlib import Path
import json,collections,random,hashlib,datetime

R=Path(r'D:\FPGA_Project\zi_guang_tong_chuang\pangoriscv\evidence\records\validation_20261104\dataset')
seed=20261104
rng=random.Random(seed)
d=json.loads((R/'valid/_annotations.coco.json').read_text())
byid=collections.defaultdict(list)
for a in d['annotations']:byid[a['image_id']].append(a)
names={c['id']:c['name'] for c in d['categories']}
chosen=[];used=set()
for cid in range(6):
    pools=[[],[],[]]
    for im in sorted(d['images'],key=lambda x:(x['file_name'],x['id'])):
        gt=byid[im['id']]
        classes={a['category_id'] for a in gt}
        if cid not in classes or im['id'] in used:continue
        tier=0 if len(gt)==1 else 1 if classes=={cid} else 2
        pools[tier].append(im)
    target=[]
    for tier,pool in enumerate(pools):
        rng.shuffle(pool)
        for im in pool:
            if len(target)>=3:break
            target.append((im,tier));used.add(im['id'])
    if len(target)!=3:raise RuntimeError('insufficient class '+str(cid))
    for im,tier in target:
        p=R/'valid'/im['file_name']
        allgt=[]
        for a in byid[im['id']]:
            x,y,w,h=a['bbox']
            allgt.append({'class_id':a['category_id'],'class_name':names[a['category_id']],
                          'box':[x,y,x+w,y+h],'bbox_xyxy':[x,y,x+w,y+h],
                          'annotation_id':a['id'],'iscrowd':a.get('iscrowd',0)})
        chosen.append(dict(index=len(chosen)+1,image_id=im['id'],file_name=im['file_name'],
             path=str(p),width=im['width'],height=im['height'],sha256=hashlib.sha256(p.read_bytes()).hexdigest(),
             target_class_id=cid,target_class_name=names[cid],selection_tier=tier,
             gt=allgt))
result=dict(seed=seed,split='validation',images=chosen,class_names=names,
    count=len(chosen),selection='For each class in fixed id order, prefer one-box images, then single-class images, then multi-class images; sort filename/id before RNG shuffle; exclude already chosen image ids; no predictions used.',
    gt_box_format='absolute image pixels xyxy; every original GT retained, including non-target classes',
    warning='18-image stratified validation re-test, not a full held-out test or deployment-population estimate; selected checkpoint was tuned/evaluated on same upstream validation split. Test split has no glass annotations.',
    annotations_sha256=hashlib.sha256((R/'valid/_annotations.coco.json').read_bytes()).hexdigest())
(R/'validation18_seed20261104.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
summary=collections.Counter(names[a['class_id']] for im in chosen for a in im['gt'])
print(json.dumps({'manifest':str(R/'validation18_seed20261104.json'),'images':len(chosen),'instances':sum(summary.values()),'instances_per_class':dict(summary),'multi_object_images':sum(len(im['gt'])>1 for im in chosen),'multi_class_images':sum(len({a['class_id'] for a in im['gt']})>1 for im in chosen)},ensure_ascii=False,indent=2))
audit=json.loads((R/'dataset_audit.json').read_text())
for split in ['test','valid']:
    sd=json.loads((R/split/'_annotations.coco.json').read_text());bc=collections.Counter(a['image_id'] for a in sd['annotations']);cs=collections.defaultdict(set)
    for a in sd['annotations']:cs[a['image_id']].add(a['category_id'])
    audit['splits'][split]['multi_object_images']=sum(v>1 for v in bc.values())
    audit['splits'][split]['multi_class_images']=sum(len(v)>1 for v in cs.values())
    audit['splits'][split]['empty_images']=len(sd['images'])-len(bc)
    audit['splits'][split]['images_per_class']={names[cid]:sum(cid in cs[im['id']] for im in sd['images']) for cid in range(6)}
    for cid in range(6):audit['splits'][split]['instances_per_class'].setdefault(names[cid],0)
audit['validation18_manifest']=str(R/'validation18_seed20261104.json')
audit['validation18_counts']=dict(summary)
audit['validation18_instances']=sum(summary.values())
audit['retrieved_utc']=datetime.datetime.now(datetime.timezone.utc).isoformat()
audit['repository_commit']='d8ad1490da2686d7af5c6a7f3d8844f0f9542b0f'
audit['source_files_manifest']=str(R/'source_documents.json')
(R/'dataset_audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2),encoding='utf-8')
(R/'数据集来源与评测边界.md').write_text('''# 数据集来源与本轮评测边界

来源：keremberke/garbage-object-detection，原始 Roboflow Material Identification 的 GARBAGE CLASSIFICATION 3 v2。

- 官方页：https://huggingface.co/datasets/keremberke/garbage-object-detection
- 原始页：https://universe.roboflow.com/material-identification/garbage-classification-3/dataset/2
- 模型页：https://huggingface.co/keremberke/yolov5n-garbage
- 数据许可证：CC BY 4.0，下载保存的 README.md 和 README.dataset.txt 可核对。
- 镜像：hf-mirror.com。仓库提交 d8ad1490da2686d7af5c6a7f3d8844f0f9542b0f。
- ZIP 已按 Hugging Face LFS SHA-256 校验，下载源文档哈希见 source_documents.json；逐split统计和ZIP哈希见 dataset_audit.json。

上游数据集包含10464张图。已取得 test 1042张和validation 2098张；原始数据预处理为416×416拉伸，图片包含上游翻转与90度旋转预处理/扩增痕迹。COCO标注 bbox 为绝对像素 xywh，类0~5依次为 biodegradable/cardboard/glass/metal/paper/plastic，可与现部署模型直接匹配。

test共3563框但glass类为0，不能利用该split得出glass AP。全test按串口82秒每图估计约23.7小时（仅用于测试时间规划，不是实测本轮速度）。

本轮板测选用 validation18_seed20261104.json：固定随机种子20261104、每个目标类选3张、总计18张，不根据预测筛选。优先单框、其次单类、最后多类；全部原始GT保留。所选图全部来自同一个validation split。它属于小样本分层验证复测，不是全量test准确率，也不能当作全系统真实场景识别率。

原模型卡本就在同源validation上报告 mAP@0.5=0.31988455750353156。这只是上游模型结果，不是本板测结果，不应冒充这次准确率。validation可能参与checkpoint选取和调参；尚未取得全部train归属及重复审计，不宣称与训练完全独立。
''',encoding='utf-8')
