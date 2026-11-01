import io
import os

import pypdf

PDS_DOC = r"E:\donwload\PDS_2022.2-SP6.4\PDS_2022.2-SP6.1\doc"
OUT = r"E:\file\pango\project\evidence\records\bottleneck_audit\contest_final\docs\pds_ref"

for name in ["Fabric_Inserter_User_Guide.pdf", "Fabric_Debugger_User_Guide.pdf"]:
    src = os.path.join(PDS_DOC, name)
    dst = os.path.join(OUT, name.replace(".pdf", ".txt"))
    reader = pypdf.PdfReader(src)
    with io.open(dst, "w", encoding="utf-8") as handle:
        for index, page in enumerate(reader.pages):
            handle.write("\n=== PAGE %d ===\n" % (index + 1))
            handle.write(page.extract_text() or "")
    print(name, len(reader.pages), os.path.getsize(dst))
