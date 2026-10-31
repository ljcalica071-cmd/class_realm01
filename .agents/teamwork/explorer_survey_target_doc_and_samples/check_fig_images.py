import zipfile
import xml.etree.ElementTree as ET

path = r"c:\Users\Admin\Downloads\Chapter2_ClassRealm_Revised_Corrected(1).docx"
NS = {
    'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
    'a': 'http://schemas.openxmlformats.org/drawingml/2006/main',
    'r': 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
}

with zipfile.ZipFile(path, 'r') as z:
    rels = ET.fromstring(z.read('word/_rels/document.xml.rels'))
    rel_map = {r.attrib['Id']: r.attrib['Target'] for r in rels}
    doc = ET.fromstring(z.read('word/document.xml'))
    
    for idx, p in enumerate(doc.findall('.//w:p', NS)):
        txt = "".join(p.itertext()).strip()
        blips = p.findall('.//a:blip', NS)
        if blips:
            rids = [b.attrib.get(f"{{{NS['r']}}}embed") for b in blips]
            targets = [rel_map.get(rid) for rid in rids]
            print(f"Paragraph {idx} text='{txt[:40]}' has images: {targets}")
