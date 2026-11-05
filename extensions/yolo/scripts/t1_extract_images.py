import zipfile, os
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
z = zipfile.ZipFile(os.path.join(root,"data","raw","trashnet-dataset-resized.zip"))
names = [n for n in z.namelist() if n.lower().endswith(('.jpg','.jpeg','.png'))]
classes = sorted(set(n.split('/')[1] for n in names if len(n.split('/'))==3))
testdir = os.path.join(root,"data","images","testset"); os.makedirs(testdir, exist_ok=True)
picked=[]
for c in classes:
    cand=[n for n in names if n.split('/')[1]==c]
    for n in cand[:2]:
        out=os.path.join(testdir, c + "__" + os.path.basename(n))
        open(out,'wb').write(z.read(n)); picked.append(out)
print("classes:", classes)
print("extracted:", len(picked), "->", testdir)
