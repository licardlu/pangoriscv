import zipfile, os, json
import onnxruntime as ort
root = r"E:\file\pango\project\ai_lab"
m = os.path.join(root, "data", "models", "garbage-detector.onnx")
s = ort.InferenceSession(m, providers=["CPUExecutionProvider"])
print("INPUTS:")
for i in s.get_inputs(): print(" ", i.name, i.shape, i.type)
print("OUTPUTS:")
for o in s.get_outputs(): print(" ", o.name, o.shape, o.type)
md = s.get_modelmeta()
print("META producer:", md.producer_name, md.producer_version, "| description:", (md.description or "")[:200])
print("CUSTOM_META:", json.dumps(dict(md.custom_metadata_map))[:500])
z = zipfile.ZipFile(os.path.join(root,"data","raw","trashnet-dataset-resized.zip"))
names = [n for n in z.namelist() if n.lower().endswith(('.jpg','.jpeg','.png'))]
print("ZIP images:", len(names), "first:", names[:2])
classes = sorted(set(n.split('/')[1] for n in names if len(n.split('/'))==3))
print("ZIP classes:", classes)
testdir = os.path.join(root,"data","images","testset")
os.makedirs(testdir, exist_ok=True)
picked=[]
for c in classes:
    cand=[n for n in names if n.split('/')[1]==c]
    for n in cand[:2]:
        out=os.path.join(testdir, c + "__" + os.path.basename(n))
        with open(out,'wb') as f: f.write(z.read(n))
        picked.append(out)
print("EXTRACTED:", len(picked))
for p in picked[:3]: print("  ", os.path.basename(p))
