import zipfile
import xml.etree.ElementTree as ET

NS = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
path = r"c:\Users\Admin\Downloads\Chapter2_ClassRealm_Revised_Corrected(1).docx"

with zipfile.ZipFile(path, 'r') as z:
    root = ET.fromstring(z.read('word/document.xml'))
    for idx, p in enumerate(root.findall('.//w:p', NS)):
        txt = "".join(p.itertext()).strip()
        if txt and (len(txt) < 80 or txt.startswith("Figure") or txt.startswith("Table") or txt.startswith("CHAPTER") or "Framework" in txt or "Synthesis" in txt):
            print(f"[{idx}] {txt}")
