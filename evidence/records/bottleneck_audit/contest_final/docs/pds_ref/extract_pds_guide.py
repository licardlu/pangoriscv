import io, os, pypdf
PDS = r"E:\donwload\PDS_2022.2-SP6.4\PDS_2022.2-SP6.1\doc"
OUT = r"E:\file\pango\project\evidence\records\bottleneck_audit\contest_final\docs\pds_ref"
name = "Pango_Design_Suite_User_Guide.pdf"
dst = os.path.join(OUT, name.replace(".pdf", ".txt"))
r = pypdf.PdfReader(os.path.join(PDS, name))
with io.open(dst, "w", encoding="utf-8") as f:
    for i, p in enumerate(r.pages):
        f.write("\n=== PAGE %d ===\n" % (i + 1))
        f.write(p.extract_text() or "")
print(name, len(r.pages), os.path.getsize(dst))
